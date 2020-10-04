// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "OpenZeppelin/openzeppelin-contracts@3.0.0/contracts/math/Math.sol";
import "OpenZeppelin/openzeppelin-contracts@3.0.0/contracts/math/SafeMath.sol";
import "OpenZeppelin/openzeppelin-contracts@3.0.0/contracts/math/SignedSafeMath.sol";
import "OpenZeppelin/openzeppelin-contracts@3.0.0/contracts/utils/Address.sol";
import "OpenZeppelin/openzeppelin-contracts@3.0.0/contracts/token/ERC20/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@3.0.0/contracts/token/ERC1155.sol";

import "../tokens/OVLToken.sol";
import "../utils/SignedMath.sol";

contract OVLFPosition is ERC1155 {
  using SafeERC20 for OVLToken;
  using Address for address;
  using SafeMath for uint256;
  using SignedSafeMath for int256;

  OVLToken public token;
  address public governance;
  address public controller;

  // TODO: params that should be settable by governance ...
  uint256 private _tradingFee;
  address private _feed;

  struct FPosition {
    uint256 balance
    bool long
    uint256 leverage
    uint256 liquidationPrice
    uint256 avgPrice
  }

  mapping (uint256 => mapping(address => FPosition)) private _positions;

  function positionOf(address _account, uint256 _id) public view returns (FPosition) {
    require(_account != address(0), "OVLFPosition: position query for the zero address");
    return _positions[_id][_account];
  }

  function build(uint256 _amount, bool _long, uint256 _leverage) public {
    token.safeTransferFrom(_msgSender(), address(this), _amount);

    // TODO: Generate position ID, then fetch price from oracle
    // feed to calculate position attrs
    uint256 price = _getPriceFromFeed(); // TODO: Verify this is safe given calling external contract view method in effects
    uint256 id = _createPosition(_amount, _long, _leverage, price);

    // Q: What should data be?
    _mint(_msgSender(), id, _amount, data);
  }

  function addTo(uint256 _id, uint256 _amount) public {
    uint256 price = _getPriceFromFeed(); // TODO: Verify this is safe given calling external contract view method in effects
    _updatePosition(_msgSender(), _id, _amount, price, true);

    // Mints more of the position NFT
    _mint(_msgSender(), _id, _amount, data);
  }

  function subFrom(uint256 _id, uint256 _amount) public {
    uint256 price = _getPriceFromFeed(); // TODO: Verify this is safe given calling external contract view method in effects
    int256 profit =_updatePosition(_msgSender(), _id, _amount, price, false);

    // Burn the position tokens being unwound
    _burn(_msgSender(), _id, _amount);

    if profit > 0 {
      // Mint the profit to this address first
      uint256 mintAmount = uint256(SignedMath.abs(profit));
      token.mint(mintAmount);

      // Update the original unwind amount
      _amount = _amount.add(mintAmount);
    } else if profit < 0 {
      // Burn the loss from this address first; make sure don't burn more
      // than original unwind amount
      uint256 burnAmount = Math.min(uint256(SignedMath.abs(profit)), _amount);
      token.burn(burnAmount);

      // Update the original unwind amount
      _amount = _amount.sub(burnAmount);
    }

    // Send principal + profit back to trader
    if _amount > 0 {
      token.safeTransfer(_msgSender(), _amount);
    }
  }

  // uwind() unlocks entire position
  function unwind(uint256 _id) public {
    uint256 amount = balanceOf(_msgSender(), _id);
    subFrom(_id, amount);
  }

  function _getPriceFromFeed() internal returns (uint256) {

  }

  function _createPosition(uint256 _amount, bool _long, uint256 _leverage, uint256 _price) internal returns (uint256) {
    // Generate the position id from pos attrs
    uint256 id = keccak256(abi.encodePacked(_long, _leverage, _price)); // TODO: Check this is safe

    // Calculate the liquidation price
    uint256 liquidationPrice = _calcLiquidationPrice(_long, _leverage, _price);

    _positions[id][_msgSender()] = FPosition(
      _amount,
      _long,
      _leverage,
      liquidationPrice,
      _price,
    );

    return id;
  }

  function _calcLiquidationPrice(bool _long, uint256 _leverage, uint256 _price) returns (uint256) {

  }

  function _updatePosition(address _account, uint256 _id, uint256 _amount, uint256 _price, bool _addTo) internal returns (int256) {
    Position memory pos = positionOf(_account, _id);

    if (_addTo) {
      // TODO: recalculate liquidationPrice, avgPrice
      pos.avgPrice = pos.avgPrice.mult(pos.balance).

      pos.balance.add(_amount);
    } else {
      // TODO: recalculate liquidationPrice, avgPrice

      pos.balance.sub(_amount);
    }

    _positions[_id][_account] = pos;
  }

  function _calcProfit(address _account, uint256 _id, uint256 _amount, uint256 _price) internal view returns (int256) {

  }
}
