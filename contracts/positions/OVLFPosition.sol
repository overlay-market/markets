// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelinV3/contracts/math/Math.sol";
import "@openzeppelinV3/contracts/math/SafeMath.sol";
import "@openzeppelinV3/contracts/math/SignedSafeMath.sol";
import "@openzeppelinV3/contracts/utils/Address.sol";
import "@openzeppelinV3/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelinV3/contracts/token/ERC1155/ERC1155.sol";

import "../tokens/OVLToken.sol";
import "../utils/SignedMath.sol";
import "../../interfaces/overlay/IOVLPosition.sol";

contract OVLFPosition is ERC1155, IOVLPosition {
  using SafeERC20 for OVLToken;
  using Address for address;
  using SafeMath for uint256;
  using SignedSafeMath for int256;

  OVLToken public token;

  uint256 public lastPrice;
  uint256 public maxLeverage = 100;
  uint256 public tradeFee = uint256(15).div(10000);
  uint256 public feeBurn = uint256(50).div(100);
  uint256 public liquidateReward = uint256(50).div(100);

  address public governance;
  address public treasury;
  address public controller;
  address public feed;

  struct FPosition {
    bool long;
    uint256 leverage;
    uint256 lockPrice;
  }

  mapping (uint256 => FPosition) private _positions;
  mapping (uint256 => bool) private _exists;
  mapping (uint256 => uint256) private _amounts; // total OVL amount locked in position


  constructor(string memory _uri, address _token, address _controller, address _feed) public ERC1155(_uri) {
    token = OVLToken(_token);
    governance = _msgSender();
    treasury = _msgSender();
    controller = _controller;
    feed = _feed;
  }

  function _positionOf(uint256 _id) private view returns (FPosition memory) {
    return _positions[_id];
  }

  function amountLockedIn(uint256 _id) public view returns (uint256) {
    return _amounts[_id];
  }

  function _positionExists(uint256 _id) private view returns (bool) {
    return _exists[_id];
  }

  function liquidationPriceOf(uint256 _id) public view returns (uint256) {
    FPosition memory pos = _positionOf(_id);
    return _calcLiquidationPrice(pos);
  }

  function _calcLiquidationPrice(FPosition memory pos) private pure returns (uint256) {
    uint256 liquidationPrice = 0;
    if (pos.long) {
      // TODO: ...
    } else {
      // TODO: ...
    }
    return liquidationPrice;
  }

  function _canLiquidate(uint256 _id, uint256 _price) private view returns (bool) {
    FPosition memory pos = _positionOf(_id);
    uint256 liquidationPrice = _calcLiquidationPrice(pos);
    bool can = false;
    if (pos.long) {
      can = (liquidationPrice >= _price);
    } else {
      can = (liquidationPrice <= _price);
    }
    return can;
  }

  // feed setters
  modifier onlyFeed() {
    require(feed == _msgSender(), "OVLFPosition: caller is not feed");
    _;
  }

  function _getPriceFromFeed() internal returns (uint256) {
    require(lastPrice != 0, "OVLFPosition: feed has not given a price yet");
    return lastPrice;
  }

  function setLastPrice(uint256 _price) external onlyFeed {
    lastPrice = _price;
  }

  // gov setters
  modifier onlyGov() {
    require(governance == _msgSender(), "OVLFPosition: caller is not governance");
    _;
  }

  function setMaxLeverage(uint256 _max) external onlyGov {
    maxLeverage = _max;
  }

  function setTradeFee(uint256 _fee) external onlyGov {
    tradeFee = _fee;
  }

  function setFeeBurn(uint256 _fee) external onlyGov {
    feeBurn = _fee;
  }

  function setLiquidateReward(uint256 _rew) external onlyGov {
    liquidateReward = _rew;
  }

  function setGovernance(address _gov) public onlyGov {
    governance = _gov;
  }

  function setTreasury(address _treasury) public onlyGov {
    treasury = _treasury;
  }

  function setController(address _controller) public onlyGov {
    controller = _controller;
  }

  function setFeed(address _feed) public onlyGov {
    feed = _feed;
  }

  // build() locks _amount in OVL into position
  function build(uint256 _amount, bool _long, uint256 _leverage) public virtual override {
    require(_leverage >= 1, "OVLFPosition: must build position with leverage at least 1");
    require(_leverage <= maxLeverage, "OVLFPosition: must build position with leverage less than max allowed");
    uint256 fees = _calcFeeAmount(_amount, _leverage);
    require(_amount > fees, "OVLFPosition: must build position with amount larger than fees");

    token.safeTransferFrom(_msgSender(), address(this), _amount);
    _amount = _amount.sub(fees);

    // Enter position with corresponding NFT receipt. 1:1 bw share of position (balance) and OVL locked for FPosition
    uint256 id = _enterPosition(_amount, _long, _leverage);
    _mint(_msgSender(), id, _amount, abi.encodePacked(uint8(0x0)));
    _transferFeesToTreasury(fees);
  }

  function buildAll(bool _long, uint256 _leverage) public virtual override {
    uint256 amount = token.balanceOf(_msgSender());
    build(amount, _long, _leverage);
  }

  // uwind() unlocks _amount in OVL from position
  function unwind(uint256 _id, uint256 _amount) public virtual override {
    // 1:1 bw share of position (balance) and OVL locked for FPosition
    require(_amount <= amountLockedIn(_id), "OVLFPosition: not enough locked in pool to unwind amount");
    _burn(_msgSender(), _id, _amount);
    int256 profit = _exitPosition(_id, _amount);

    if (profit > 0) {
      uint256 mintAmount = uint256(SignedMath.abs(profit));
      token.mint(mintAmount);
      _amount = _amount.add(mintAmount);
    } else if (profit < 0) {
      // Make sure don't burn more than original unwind amount
      uint256 burnAmount = Math.min(uint256(SignedMath.abs(profit)), _amount);
      token.burn(burnAmount);
      _amount = _amount.sub(burnAmount);
    }

    FPosition memory pos = _positionOf(_id);
    uint256 fees = _calcFeeAmount(_amount, pos.leverage);
    _amount = _amount.sub(fees);

    // Send principal + profit back to trader and fees to treasury
    if (_amount > 0) {
      token.safeTransfer(_msgSender(), _amount);
      _transferFeesToTreasury(fees);
    }
  }

  // uwindAll() unlocks entire position
  function unwindAll(uint256 _id) public virtual override {
    uint256 amount = balanceOf(_msgSender(), _id);
    unwind(_id, amount);
  }

  // liquidate() burns underwater positions
  function liquidate(uint256 _id) public virtual override {
    require(_positionExists(_id), "OVLFPosition: position must exist");
    uint256 price = _getPriceFromFeed();
    require(_canLiquidate(_id, price), "OVLFPosition: position must be underwater");

    uint256 amount = amountLockedIn(_id);
    _amounts[_id] = 0;

    // send fees to treasury and transfer rest to liquidater
    uint256 rew = amount.mul(liquidateReward);
    amount = amount.sub(rew);
    token.safeTransfer(_msgSender(), rew);
    _transferFeesToTreasury(amount);
  }

  function _enterPosition(uint256 _amount, bool _long, uint256 _leverage) private returns (uint256) {
    uint256 price = _getPriceFromFeed();
    uint256 id = _getId(_long, _leverage, price);

    if (!_positionExists(id)) {
      _positions[id] = FPosition(_long, _leverage, price);
      _exists[id] = true;
    }

    // update total locked amount
    uint256 amountLocked = amountLockedIn(id);
    _amounts[id] = amountLocked.add(_amount);

    return id;
  }

  function _exitPosition(uint256 _id, uint256 _amount) private returns (int256) {
    uint256 price = _getPriceFromFeed();
    int256 profit = _calcProfit(_id, _amount, price);

    // update total locked amount
    uint256 amountLocked = amountLockedIn(_id);
    _amounts[_id] = amountLocked.sub(_amount);

    return profit;
  }

  function _calcFeeAmount(uint256 _amount, uint256 _leverage) internal view returns (uint256) {
    return _amount.mul(_leverage).mul(tradeFee);
  }

  function _transferFeesToTreasury(uint256 fees) private {
    uint256 burnAmount = fees.mul(feeBurn);
    token.burn(burnAmount);

    fees = fees.sub(burnAmount);
    token.safeTransfer(treasury, fees);
  }

  function _getId(bool _long, uint256 _leverage, uint256 _price) private pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(_long, _leverage, _price))); // TODO: Check this is safe
  }

  function _calcProfit(uint256 _id, uint256 _amount, uint256 _price) internal view returns (int256) {

  }
}
