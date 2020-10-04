// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

interface IOVLFeed {

  function getLatestPrice() external returns (uint256);

}
