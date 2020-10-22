// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.0;

import "@openzeppelinV3/contracts/GSN/Context.sol";
import "@openzeppelinV3/contracts/math/SafeMath.sol";
import "@openzeppelinV3/contracts/utils/Address.sol";
import "@openzeppelinV3/contracts/token/ERC20/IERC20.sol";
import "@openzeppelinV3/contracts/token/ERC20/SafeERC20.sol";

contract OVLClaim is Context {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  IERC20 public token;
  uint256 public amount;
  mapping (address => bool) private _hasClaimed;

  event Withdraw(address indexed by, uint256 value);

  constructor(address _token, uint256 _amount) public {
    token = IERC20(_token);
    amount = _amount;
  }

  function withdraw() external {
    require(!_hasClaimed[_msgSender()], "OVLClaim: must not have already withdrawn");
    uint256 funds = token.balanceOf(address(this));
    require(funds >= amount, "OVLClaim: no more funds to withdraw");
    _hasClaimed[_msgSender()] = true;
    token.safeTransfer(_msgSender(), amount);
    emit Withdraw(_msgSender(), amount);
  }

  function hasClaimed(address _addr) external view returns (bool) {
    return _hasClaimed[_addr];
  }
}
