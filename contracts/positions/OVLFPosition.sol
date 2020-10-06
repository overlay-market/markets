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
  address public governance;
  address public controller;
  address public treasury; // TODO: should this and governance be the same?

  // TODO: params that should be settable by governance ...
  address private feed;
  uint256 private tradeFeePerc;
  uint256 private feeBurnPerc;

  struct FPosition {
    bool long;
    uint256 leverage;
    uint256 balance;
    uint256 liquidationPrice;
    uint256 lockPrice;
  }

  mapping (uint256 => mapping(address => FPosition)) private _positions;

  constructor(string memory _uri, address _token, address _controller, address _feed) public ERC1155(_uri) {
    token = OVLToken(_token);
    governance = _msgSender();
    controller = _controller;
    feed = _feed;
  }

  function _positionOf(address _account, uint256 _id) private view returns (FPosition memory) {
    require(_account != address(0), "OVLFPosition: position query for the zero address");
    return _positions[_id][_account];
  }

  // build() locks _amount in OVL into position
  function build(uint256 _amount, bool _long, uint256 _leverage) public virtual override {
    uint256 tradeFee = _calcTradeFee(_amount, _leverage);
    require(_amount > tradeFee, "OVLFPosition: must build position with amount larger than fees");
    token.safeTransferFrom(_msgSender(), address(this), _amount);
    _amount = _amount.sub(tradeFee);

    // Create the position NFT
    uint256 id = _createPosition(_amount, _long, _leverage);
    _mint(_msgSender(), id, _amount, abi.encodePacked(uint8(0x0)));
    _transferFeesToTreasury(tradeFee);
  }

  function buildAll(bool _long, uint256 _leverage) public virtual override {
    uint256 amount = token.balanceOf(_msgSender());
    build(amount, _long, _leverage);
  }

  // uwind() unlocks _amount in OVL from position
  function unwind(uint256 _id, uint256 _amount) public virtual override {
    _burn(_msgSender(), _id, _amount);
    int256 profit =_updatePositionOnUnwind(_msgSender(), _id, _amount);

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

    FPosition memory pos = _positionOf(_msgSender(), _id);
    uint256 tradeFee = _calcTradeFee(_amount, pos.leverage);
    _amount = _amount.sub(tradeFee);

    // Send principal + profit back to trader and fees to treasury
    if (_amount > 0) {
      token.safeTransfer(_msgSender(), _amount);
      _transferFeesToTreasury(tradeFee);
    }
  }

  // uwindAll() unlocks entire position
  function unwindAll(uint256 _id) public virtual override {
    uint256 amount = balanceOf(_msgSender(), _id);
    unwind(_id, amount);
  }

  function _getPriceFromFeed() internal returns (uint256) {

  }

  function _transferFeesToTreasury(uint256 fees) private {
    uint256 burnAmount = fees.mul(feeBurnPerc).div(100);
    token.burn(burnAmount);

    fees.sub(burnAmount);
    token.safeTransfer(treasury, fees);
  }

  function _createPosition(uint256 _amount, bool _long, uint256 _leverage) private returns (uint256) {
    uint256 price = _getPriceFromFeed();
    uint256 id = uint256(keccak256(abi.encodePacked(_long, _leverage, price))); // TODO: Check this is safe
    uint256 liquidationPrice = _calcLiquidationPrice(_amount, _long, _leverage, price);
    _positions[id][_msgSender()] = FPosition(
      _long,
      _leverage,
      _amount,
      liquidationPrice,
      price
    );
    return id;
  }

  function _calcTradeFee(uint256 _amount, uint256 _leverage) internal view returns (uint256) {
    return _amount.mul(_leverage).mul(tradeFeePerc).div(100); // TODO: make sure this is right here
  }

  function _updatePositionOnUnwind(address _account, uint256 _id, uint256 _amount) private returns (int256) {
    FPosition memory pos = _positionOf(_account, _id);
    uint256 price = _getPriceFromFeed();
    int256 profit = _calcProfit(pos, _amount, price);

    // TODO: recalculate liquidationPrice
    pos.balance.sub(_amount);
    _positions[_id][_account] = pos;

    return profit;
  }

  function _calcLiquidationPrice(uint256 _amount, bool _long, uint256 _leverage, uint256 _price) internal view returns (uint256) {

  }

  function _calcProfit(FPosition memory position, uint256 _amount, uint256 _price) internal view returns (int256) {

  }

  function _calcPercPnL(FPosition memory position, uint256 _price) internal view returns (int256) {

  }
}
