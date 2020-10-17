// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.0;

interface IOVLFeed {

  function getData() external returns (int256, uint256);

}
