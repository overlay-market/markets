// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.0;

interface IOVLToken {

  function mint(uint256 _amount) external;

  function burn(uint256 _amount) external;

}
