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

  // TODO: params that should be settable by governance ...
  uint256 private tradingFee;
  address private feed;

  struct FPosition {
    uint256 balance;
    bool long;
    uint256 leverage;
    uint256 liquidationPrice;
    uint256 price;
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

  function build(uint256 _amount, bool _long, uint256 _leverage) public virtual override {
    token.safeTransferFrom(_msgSender(), address(this), _amount);

    // TODO: Generate position ID, then fetch price from oracle
    // feed to calculate position attrs
    uint256 price = _getPriceFromFeed(); // TODO: Verify this is safe given calling external contract view method in effects
    uint256 id = _createPosition(_amount, _long, _leverage, price);

    // Q: What should data param be for _mint?
    _mint(_msgSender(), id, _amount, abi.encodePacked(uint8(0x0)));
  }

  // uwind() unlocks _amount of position
  function unwind(uint256 _id, uint256 _amount) public virtual override {
    uint256 price = _getPriceFromFeed(); // TODO: Verify this is safe given calling external contract view method in effects
    int256 profit =_updatePositionOnUnwind(_msgSender(), _id, _amount, price);

    // Burn the position tokens being unwound
    _burn(_msgSender(), _id, _amount);

    if (profit > 0) {
      // Mint the profit to this address first
      uint256 mintAmount = uint256(SignedMath.abs(profit));
      token.mint(mintAmount);

      // Update the original unwind amount
      _amount = _amount.add(mintAmount);
    } else if (profit < 0) {
      // Burn the loss from this address first; make sure don't burn more
      // than original unwind amount
      uint256 burnAmount = Math.min(uint256(SignedMath.abs(profit)), _amount);
      token.burn(burnAmount);

      // Update the original unwind amount
      _amount = _amount.sub(burnAmount);
    }

    // Send principal + profit back to trader
    if (_amount > 0) {
      token.safeTransfer(_msgSender(), _amount);
    }
  }

  // uwindAll() unlocks entire position
  function unwindAll(uint256 _id) public virtual override {
    uint256 amount = balanceOf(_msgSender(), _id);
    unwind(_id, amount);
  }

  function _getPriceFromFeed() internal returns (uint256) {

  }

  function _createPosition(uint256 _amount, bool _long, uint256 _leverage, uint256 _price) private returns (uint256) {
    // Generate the position id from pos attrs
    uint256 id = uint256(keccak256(abi.encodePacked(_long, _leverage, _price))); // TODO: Check this is safe

    // Calculate the liquidation price
    uint256 liquidationPrice = _calcLiquidationPrice(_long, _leverage, _price);

    _positions[id][_msgSender()] = FPosition(
      _amount,
      _long,
      _leverage,
      liquidationPrice,
      _price
    );

    return id;
  }

  function _calcLiquidationPrice(bool _long, uint256 _leverage, uint256 _price) private view returns (uint256) {

  }

  function _updatePositionOnUnwind(address _account, uint256 _id, uint256 _amount, uint256 _price) private returns (int256) {
    FPosition memory pos = _positionOf(_account, _id);
    int256 profit = _calcProfit(pos, _amount, _price);

    // TODO: recalculate liquidationPrice
    pos.balance.sub(_amount);

    _positions[_id][_account] = pos;

    return profit;
  }

  function _calcProfit(FPosition memory position, uint256 _amount, uint256 _price) private view returns (int256) {

  }

  function _calcPercPnL(FPosition memory position, uint256 _price) private view returns (int256) {

  }
}
