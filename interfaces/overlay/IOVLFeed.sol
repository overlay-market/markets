// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.0;

interface IOVLFeed {

  function getLatestPrice() external returns (uint256);

}
