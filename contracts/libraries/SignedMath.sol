// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";

library SignedMath {

  using SignedSafeMath for int256;

  function abs(int256 a) internal pure returns (int256) {
    return a >= 0 ? a : a.mul(-1);
  }

}
