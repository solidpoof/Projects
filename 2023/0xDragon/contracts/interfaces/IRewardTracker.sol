// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.8.18;

interface IRewardTracker {
    function updateRewards() external;

    function claimForAccount(address account) external;
}
