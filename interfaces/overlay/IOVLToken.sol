// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

interface IOVLToken {

  function mint(uint256 _amount) external;

  function burn(uint256 _amount) external;

}
