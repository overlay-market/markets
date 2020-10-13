// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.2;

import "@openzeppelinV3/contracts/math/Math.sol";
import "@openzeppelinV3/contracts/math/SafeMath.sol";
import "@openzeppelinV3/contracts/math/SignedSafeMath.sol";
import "@openzeppelinV3/contracts/utils/Address.sol";
import "@openzeppelinV3/contracts/utils/EnumerableSet.sol";
import "@openzeppelinV3/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelinV3/contracts/token/ERC1155/ERC1155.sol";

import "../tokens/OVLToken.sol";
import "../utils/SignedMath.sol";
import "../../interfaces/overlay/IOVLPosition.sol";
import "../../interfaces/overlay/IOVLFeed.sol";

contract OVLFPosition is ERC1155, IOVLPosition {
  using SafeERC20 for OVLToken;
  using Address for address;
  using SafeMath for uint256;
  using SignedSafeMath for int256;
  using EnumerableSet for EnumerableSet.UintSet;

  OVLToken public immutable token;
  IOVLFeed public feed;

  uint256 public constant BASE = 1e18;
  uint256 public constant MIN_LEVERAGE = 1e18;
  uint256 public constant FEE_BURN = 50 * 1e16;
  uint256 public constant LIQUIDATE_REWARD = 50 * 1e16;

  // TODO: decimals ..

  uint256 public maxLeverage = BASE.mul(10);
  uint256 public tradeFee = BASE.mul(15).div(10000);

  address public governance;
  address public treasury;

  struct FPosition {
    bool long;
    uint256 leverage;
    int256 lockPrice;
  }

  mapping (uint256 => FPosition) private _positions;
  mapping (uint256 => uint256) private _amounts; // total OVL amount locked in position

  EnumerableSet.UintSet private _open;

  constructor(string memory _uri, address _token, address _feed) public ERC1155(_uri) {
    token = OVLToken(_token);
    governance = _msgSender();
    treasury = _msgSender();
    feed = IOVLFeed(_feed);
  }

  // build() locks _amount in OVL into position
  function build(uint256 _amount, bool _long, uint256 _leverage) public virtual override {
    require(_amount > 0, "OVLFPosition: must build position with amount greater than zero");
    require(_leverage >= MIN_LEVERAGE, "OVLFPosition: must build position with leverage greater than min allowed");
    require(_leverage <= maxLeverage, "OVLFPosition: must build position with leverage less than max allowed");
    uint256 fees = _calcFeeAmount(_amount, _leverage);
    require(_amount > fees, "OVLFPosition: must build position with amount larger than fees");

    token.safeTransferFrom(_msgSender(), address(this), _amount);
    _amount = _amount.sub(fees);

    // Enter position with corresponding receipt. 1:1 bw share of position (balance) and OVL locked for FPosition
    uint256 id = _enterPosition(_amount, _long, _leverage);
    _mint(_msgSender(), id, _amount, "0x0");
    _transferFeesToTreasury(fees);
    emit Build(_msgSender(), id, _amount);
  }

  function buildAll(bool _long, uint256 _leverage) public virtual override {
    uint256 amount = token.balanceOf(_msgSender());
    build(amount, _long, _leverage);
  }

  // uwind() unlocks _amount in OVL from position
  function unwind(uint256 _id, uint256 _amount) public virtual override {
    // 1:1 bw share of position (balance) and OVL locked for FPosition
    require(_amount > 0, "OVLFPosition: must unwind position with amount greater than zero");
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
    emit Unwind(_msgSender(), _id, _amount);
  }

  // uwindAll() unlocks entire position
  function unwindAll(uint256 _id) public virtual override {
    uint256 amount = balanceOf(_msgSender(), _id);
    unwind(_id, amount);
  }

  // liquidate() burns underwater positions
  function liquidate(uint256 _id) public virtual override {
    require(_positionExists(_id), "OVLFPosition: position must exist");
    int256 price = feed.getData();
    require(_canLiquidate(_id, price), "OVLFPosition: position must be underwater");

    uint256 amount = amountLockedIn(_id);
    _amounts[_id] = 0;
    _open.remove(_id);

    // send fees to treasury and transfer rest to liquidater
    uint256 reward = amount.mul(LIQUIDATE_REWARD).div(BASE);
    amount = amount.sub(reward);
    token.safeTransfer(_msgSender(), reward);
    _transferFeesToTreasury(amount);
    emit Liquidate(_msgSender(), _id, reward);
  }

  // liquidatable() lists underwater positions
  function liquidatable() public view virtual override returns (uint256[] memory) {
    int256 price = feed.getData();
    uint256[] memory liqs = new uint256[](_open.length()); // TODO: len > liqs.length, which produces empty zero values at the end of ret array. Is this a problem ever with keccak() ids and an edge case?
    for (uint256 i=0; i < _open.length(); i++) {
      uint256 id = _open.at(i);
      if (_canLiquidate(id, price)) {
        liqs[i] = id;
      }
    }
    return liqs;
  }

  function _enterPosition(uint256 _amount, bool _long, uint256 _leverage) private returns (uint256) {
    int256 price = feed.getData();
    uint256 id = getId(_long, _leverage, price);

    if (!_positionExists(id)) {
      _positions[id] = FPosition(_long, _leverage, price);
      _open.add(id);
    }

    // update total locked amount
    uint256 amountLocked = amountLockedIn(id);
    _amounts[id] = amountLocked.add(_amount);

    return id;
  }

  function _exitPosition(uint256 _id, uint256 _amount) private returns (int256) {
    int256 price = feed.getData();
    int256 profit = _calcProfit(_id, _amount, price);

    // update total locked amount
    uint256 amountLocked = amountLockedIn(_id);
    _amounts[_id] = amountLocked.sub(_amount);

    return profit;
  }

  function _calcProfit(uint256 _id, uint256 _amount, int256 _price) internal view returns (int256) {
    // pnl = (exit - entry)/entry * side * leverage * amount
    FPosition memory pos = _positionOf(_id);
    int256 side = pos.long ? int256(1) : int256(-1);
    int256 size = int256(_amount).mul(int256(pos.leverage));
    int256 ratio = _price.sub(pos.lockPrice).mul(int256(BASE)).div(pos.lockPrice);
    return size.mul(side).mul(ratio).div(int256(BASE)).div(int256(BASE)); // TODO: Check for any rounding errors
  }

  function _calcLiquidationPrice(FPosition memory pos) private pure returns (int256) {
    int256 liquidationPrice;
    if (pos.long) {
      // liquidate = lockPrice * (1-1/leverage); liquidate when pnl = -amount so no debt
      liquidationPrice = pos.lockPrice.mul(int256(pos.leverage.sub(BASE))).div(int256(pos.leverage));
    } else {
      // liquidate = lockPrice * (1+1/leverage)
      liquidationPrice = pos.lockPrice.mul(int256(pos.leverage.add(BASE))).div(int256(pos.leverage));
    }
    return liquidationPrice;
  }

  function _canLiquidate(uint256 _id, int256 _price) private view returns (bool) {
    FPosition memory pos = _positionOf(_id);
    int256 liquidationPrice = _calcLiquidationPrice(pos);
    bool can = false;
    if (pos.long) {
      can = (liquidationPrice >= _price);
    } else {
      can = (liquidationPrice <= _price);
    }
    return can;
  }

  function _calcFeeAmount(uint256 _amount, uint256 _leverage) internal view returns (uint256) {
    return _amount.mul(_leverage).mul(tradeFee).div(BASE).div(BASE);
  }

  function _transferFeesToTreasury(uint256 fees) private {
    uint256 burnAmount = fees.mul(FEE_BURN).div(BASE);
    token.burn(burnAmount);

    fees = fees.sub(burnAmount);
    token.safeTransfer(treasury, fees);
  }

  // pos attr views
  function _positionOf(uint256 _id) private view returns (FPosition memory) {
    require(_positionExists(_id), "OVLFPosition: position must exist"); // TODO: change this so doesn't revert but fix fns below?
    return _positions[_id];
  }

  function _positionExists(uint256 _id) private view returns (bool) {
    return _open.contains(_id);
  }

  function getId(bool _long, uint256 _leverage, int256 _price) public pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(_long, _leverage, _price))); // TODO: Check this is safe
  }

  function amountLockedIn(uint256 _id) public view returns (uint256) {
    return _amounts[_id];
  }

  function isLong(uint256 _id) public view returns (bool) {
    FPosition memory pos = _positionOf(_id);
    return pos.long;
  }

  function leverageOf(uint256 _id) public view returns (uint256) {
    FPosition memory pos = _positionOf(_id);
    return pos.leverage;
  }

  function lockPriceOf(uint256 _id) public view returns (int256) {
    FPosition memory pos = _positionOf(_id);
    return pos.lockPrice;
  }

  function liquidationPriceOf(uint256 _id) public view returns (int256) {
    FPosition memory pos = _positionOf(_id);
    return _calcLiquidationPrice(pos);
  }

  function open() public view returns (uint256[] memory) {
    uint256[] memory ps = new uint256[](_open.length());
    for (uint256 i=0; i < _open.length(); i++) {
      uint256 id = _open.at(i);
      ps[i] = id;
    }
    return ps;
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

  function setGovernance(address _gov) public onlyGov {
    governance = _gov;
  }

  function setTreasury(address _treasury) public onlyGov {
    treasury = _treasury;
  }

  function setFeed(address _feed) public onlyGov {
    feed = IOVLFeed(_feed);
  }
}
