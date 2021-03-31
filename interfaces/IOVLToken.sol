// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IOVLToken is IERC20 {

  function mint(address _recipient, uint256 _amount) external;

  function burn(address _account, uint256 _amount) external;

}
