// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "./libraries/SignedMath.sol";
import "../interfaces/IOVLToken.sol";
import "../interfaces/IOVLFeed.sol";

contract OVLFPosition is ERC1155 {
  using SafeERC20 for IOVLToken;
  using Address for address;
  using SafeMath for uint256;
  using SignedSafeMath for int256;
  using EnumerableSet for EnumerableSet.UintSet;

  IOVLToken public token;
  IOVLFeed public feed;

  uint256 private constant BASE = 1e18;
  uint256 public constant MIN_LEVERAGE = 1e18;

  uint8 public decimals = 18;

  // TODO: Fix this
  uint256 public maxLeverage = BASE.mul(10);
  uint256 public tradeFee = BASE.mul(15).div(10000);
  uint256 public feeBurn = BASE.mul(50).div(100);
  uint256 public liquidateReward = BASE.mul(50).div(100);

  address public governance;
  address public treasury;

  struct FPosition {
    bool long;
    uint256 leverage;
    int256 lockPrice;
  }

  event Build(
    address indexed _account,
    uint indexed _id,
    uint _amount
  );
  event Unwind(
    address indexed _account,
    uint indexed _id,
    uint _amount
  );
  event Liquidate(
    address indexed _account,
    uint indexed _id,
    uint _amount
  );

  mapping (uint256 => FPosition) private _positions;
  mapping (uint256 => uint256) private _amounts; // total OVL amount locked in position

  EnumerableSet.UintSet private _open;

  constructor(string memory _uri, address _token, address _feed) ERC1155(_uri) {
    token = IOVLToken(_token);
    feed = IOVLFeed(_feed);
    governance = msg.sender;
    treasury = msg.sender;
  }

  // build() locks _amount in OVL into position
  function build(uint256 _amount, bool _long, uint256 _leverage) public {
    require(_amount > 0, "OVLFPosition: must build position with amount greater than zero");
    require(_leverage >= MIN_LEVERAGE, "OVLFPosition: must build position with leverage greater than min allowed");
    require(_leverage <= maxLeverage, "OVLFPosition: must build position with leverage less than max allowed");

    token.safeTransferFrom(msg.sender, address(this), _amount);
    uint256 fees = _calcFeeAmount(_amount, _leverage);
    _amount = _amount.sub(fees);

    // Enter position with corresponding receipt. 1:1 bw share of position (balance) and OVL locked for FPosition
    uint256 id = _enterPosition(_amount, _long, _leverage);
    _mint(msg.sender, id, _amount, "");
    _transferFeesToTreasury(fees);
    emit Build(msg.sender, id, _amount);
  }

  function buildAll(bool _long, uint256 _leverage) public {
    uint256 amount = token.balanceOf(msg.sender);
    build(amount, _long, _leverage);
  }

  // uwind() unlocks _amount in OVL from position
  function unwind(uint256 _id, uint256 _amount) public {
    // 1:1 bw share of position (balance) and OVL locked for FPosition
    require(_amount > 0, "OVLFPosition: must unwind position with amount greater than zero");
    require(_amount <= amountLockedIn(_id), "OVLFPosition: not enough locked in pool to unwind amount");

    _burn(msg.sender, _id, _amount);
    int256 profit = _exitPosition(_id, _amount);

    if (profit > 0) {
      uint256 mintAmount = uint256(SignedMath.abs(profit));
      token.mint(msg.sender, mintAmount);
      _amount = _amount.add(mintAmount);
    } else if (profit < 0) {
      // Make sure don't burn more than original unwind amount
      uint256 burnAmount = Math.min(uint256(SignedMath.abs(profit)), _amount);
      token.burn(msg.sender, burnAmount);
      _amount = _amount.sub(burnAmount);
    }

    uint256 leverage = leverageOf(_id);
    uint256 fees = _calcFeeAmount(_amount, leverage);
    _amount = _amount.sub(fees);

    // Send principal + profit back to trader and fees to treasury
    if (_amount > 0) {
      token.safeTransfer(msg.sender, _amount);
      _transferFeesToTreasury(fees);
    }
    emit Unwind(msg.sender, _id, _amount);
  }

  // uwindAll() unlocks entire position
  function unwindAll(uint256 _id) public {
    uint256 amount = balanceOf(msg.sender, _id);
    unwind(_id, amount);
  }

  // liquidate() burns underwater positions
  function liquidate(uint256 _id) public {
    require(_positionExists(_id), "OVLFPosition: position must exist");
    int256 price = _getPrice();
    require(_canLiquidate(_id, price), "OVLFPosition: position must be underwater");

    uint256 amount = amountLockedIn(_id);
    uint256 leverage = leverageOf(_id);
    uint256 fees = _calcFeeAmount(amount, leverage);
    amount = amount.sub(fees);

    _amounts[_id] = 0;
    _open.remove(_id);

    // send fees to treasury and transfer rest to liquidater
    uint256 reward = amount.mul(liquidateReward).div(BASE);
    amount = amount.sub(reward);
    token.burn(msg.sender, amount);
    token.safeTransfer(msg.sender, reward);
    _transferFeesToTreasury(fees);
    emit Liquidate(msg.sender, _id, reward);
  }

  // liquidatable() lists underwater positions
  function liquidatable() public returns (uint256[] memory) {
    int256 price = _getPrice();
    uint256[] memory liqs = new uint256[](_open.length()); // TODO: len > liqs.length, which produces empty zero values at the end of ret array. Is this a problem ever with keccak() ids and an edge case?
    for (uint256 i=0; i < _open.length(); i++) {
      uint256 id = _open.at(i);
      if (_canLiquidate(id, price)) {
        liqs[i] = id;
      }
    }
    return liqs;
  }

  function open() public view returns (uint256[] memory) {
    uint256[] memory ps = new uint256[](_open.length());
    for (uint256 i=0; i < _open.length(); i++) {
      uint256 id = _open.at(i);
      ps[i] = id;
    }
    return ps;
  }

  function _enterPosition(uint256 _amount, bool _long, uint256 _leverage) private returns (uint256) {
    int256 price = _getPrice();
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
    int256 price = _getPrice();
    int256 profit = _calcProfit(_id, _amount, price);

    // update total locked amount
    uint256 amountLocked = amountLockedIn(_id);
    _amounts[_id] = amountLocked.sub(_amount);

    return profit;
  }

  function _getPrice() private returns (int256) {
    (int256 price, ) = feed.fetchData();
    return price;
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
    return Math.min(_amount.mul(_leverage).mul(tradeFee).div(BASE).div(BASE), _amount);
  }

  function _transferFeesToTreasury(uint256 fees) private {
    uint256 burnAmount = fees.mul(feeBurn).div(BASE);
    token.burn(msg.sender, burnAmount);

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

  // TODO: Check this is safe and unique
  function getId(bool _long, uint256 _leverage, int256 _price) public pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(_long, _leverage, _price)));
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

  // gov setters
  modifier onlyGov() {
    require(governance == msg.sender, "not governance");
    _;
  }

  function setMaxLeverage(uint256 _max) external onlyGov {
    maxLeverage = _max;
  }

  function setTradeFee(uint256 _fee) external onlyGov {
    tradeFee = _fee;
  }

  function setFeeBurn(uint256 _burn) external onlyGov {
    feeBurn = _burn;
  }

  function setLiquidateReward(uint256 _reward) external onlyGov {
    liquidateReward = _reward;
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
