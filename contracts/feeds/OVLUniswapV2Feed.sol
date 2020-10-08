// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.0;

import "../../interfaces/overlay/IOVLFeed.sol";

contract OVLUniswapV2Feed is IOVLFeed {

  function getLatestPrice() public virtual override returns (uint256) {

  }

}
