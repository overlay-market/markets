// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

interface IOVLPosition {

  function build(uint256 _amount, bool _long, uint256 leverage) public;

  function unwind(uint256 _id, uint256 _amount) public;

  function unwindAll(uint256 _id) public;

}
