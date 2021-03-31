// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OVLClaim {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  IERC20 public token;
  uint256 public amount;
  mapping (address => bool) private _hasClaimed;

  event Withdraw(address indexed by, uint256 value);

  constructor(address _token, uint256 _amount) {
    token = IERC20(_token);
    amount = _amount;
  }

  function withdraw() external {
    require(!_hasClaimed[msg.sender], "OVLClaim: must not have already withdrawn");
    uint256 funds = token.balanceOf(address(this));
    require(funds >= amount, "OVLClaim: no more funds to withdraw");
    _hasClaimed[msg.sender] = true;
    token.safeTransfer(msg.sender, amount);
    emit Withdraw(msg.sender, amount);
  }

  function hasClaimed(address _addr) external view returns (bool) {
    return _hasClaimed[_addr];
  }
}
