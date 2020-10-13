// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.0;

interface IOVLPosition {

  function build(uint256 _amount, bool _long, uint256 _leverage) external;

  function buildAll(bool _long, uint256 _leverage) external;

  function unwind(uint256 _id, uint256 _amount) external;

  function unwindAll(uint256 _id) external;

  function liquidate(uint256 _id) external;

  function liquidatable() external view returns (uint256[] memory);

  event Build(address indexed by, uint256 indexed id, uint256 value);

  event Unwind(address indexed by, uint256 indexed id, uint256 value);

  event Liquidate(address indexed by, uint256 indexed id, uint256 value);
}
