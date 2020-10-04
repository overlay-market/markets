// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "OpenZeppelin/openzeppelin-contracts@3.0.0/contracts/math/Math.sol";
import "OpenZeppelin/openzeppelin-contracts@3.0.0/contracts/math/SafeMath.sol";
import "OpenZeppelin/openzeppelin-contracts@3.0.0/contracts/math/SignedSafeMath.sol";
import "OpenZeppelin/openzeppelin-contracts@3.0.0/contracts/utils/Address.sol";
import "OpenZeppelin/openzeppelin-contracts@3.0.0/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@3.0.0/contracts/token/ERC20/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@3.0.0/contracts/token/ERC1155.sol";

import "../tokens/OVLToken.sol";
import "../utils/SignedMath.sol";

contract OVLPosition is ERC1155 {
  using SafeERC20 for IERC20;
  using OVLToken for IERC20; // NOTE: Make sure this multiple using for IERC20 works properly
  using Address for address;
  using SafeMath for uint256;
  using SignedSafeMath for int256;

  IERC20 public token;
  uint256 private _tradingFee;

  struct Position {
    bool long
    uint256 balance
    uint256 leverage
    uint256 liquidationPrice
    uint256 avgPrice
  }

  mapping (uint256 => mapping(address => Position)) private _positions;

  function detailsOf(address _account, uint256 _id) public view returns (Position) {
    require(_account != address(0), "OVLPosition: position query for the zero address");
    return _positions[_id][_account];
  }

  function _calcProfit(address _account, uint256 _id, uint256 _amount) internal view returns (int256) {
    // TODO: ...
  }

  function build(uint256 _amount, bool _long, uint256 leverage) public {
    token.safeTransferFrom(_msgSender(), address(this), _amount);

    // TODO: Generate position ID, then fetch price from oracle
    // feed to calculate position attrs

    // Mint the position NFT
    _mint(_msgSender(), id, _amount, data);
  }

  function addTo(uint256 _id, uint256 _amount) public {

  }

  function subFrom(uint256 _id, uint256 _amount) public {
    int256 profit = _calcProfit(_msgSender(), _id, _amount);

    // Burn the position tokens being unwound
    // TODO: Need to zero the position in _positions as well (include that in an override of _burn function)
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

  function unwind(uint256 _id) public {
    uint256 amount = balanceOf(_msgSender(), _id);
    subFrom(_id, amount);
  }
}
