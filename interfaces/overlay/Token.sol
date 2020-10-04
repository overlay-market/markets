// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

interface IOVLToken {

    function mint(address _to, uint256 _amount) public;

    function burn(uint256 _amount) public;

}
