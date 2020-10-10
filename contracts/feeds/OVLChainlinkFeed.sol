// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.7;

import "@openzeppelinV3/contracts/GSN/Context.sol";
import "@openzeppelinV3/contracts/math/SignedSafeMath.sol";

import "../../interfaces/chainlink/AggregatorV3Interface.sol";
import "../../interfaces/overlay/IOVLFeed.sol";
import "../../interfaces/overlay/IOVLPosition.sol";

contract OVLChainlinkFeed is Context, IOVLFeed {
  AggregatorV3Interface internal chainlink;
  IOVLPosition public market;
  address public governance;

  constructor(address _market, address _chainlink) public {
    market = IOVLPosition(_market);
    chainlink = AggregatorV3Interface(_chainlink);
    governance = _msgSender();
  }

  function _get() private returns (int256) {
    // TODO: twap implementation?
    (, int256 price, , uint256 timestamp, ) = chainlink.latestRoundData();
    require(timestamp > 0, "OVLChainlinkFeed: round not complete");
    return price;
  }

  function _set(int256 _price) private {
    market.updatePrice(_price);
  }

  // Gets latest spot price then sets in position contract
  function update() public virtual override {
    int256 price = _get();
    _set(price);
  }

  // gov setters
  modifier onlyGov() {
    require(governance == _msgSender(), "OVLChainlinkFeed: caller is not governance");
    _;
  }

  function setGovernance(address _gov) public onlyGov {
    governance = _gov;
  }

  function setMarket(address _market) public onlyGov {
    market = IOVLPosition(_market);
  }

  function setChainlink(address _chainlink) public onlyGov {
    chainlink = AggregatorV3Interface(_chainlink);
  }
}
