// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

interface IOVLPosition {

  function build(uint256 _amount, bool _long, uint256 _leverage) external;

  function unwind(uint256 _id, uint256 _amount) external;

  function unwindAll(uint256 _id) external;

}
