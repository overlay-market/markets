from brownie import OVLToken, OVLFPosition, OVLChainlinkFeed, accounts
from brownie._config import CONFIG

chainlink_addrs = {
    "BTCUSD": {
        "mainnet": "0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c",
        "rinkeby": "0xECe365B379E1dD183B20fc5f022230C044d51404",
        "kovan": "0x6135b13325bfC4B00278B4abC5e20bbce2D6580e",
        "mainnet-fork": "0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c", # won't work on ganache-cli testnet
    }
}

def main():
    network = CONFIG.active_network['id']
    print("Deploying to {} ...".format(network))

    # Deploy OVL ERC20 with minter role given to deployer
    acct = accounts.load('test_1') # TODO: ovl_deployer

    # TODO: fix gas price issues with kovan deployment
    token = OVLToken.deploy("Overlay", "OVL", {
        'from': acct,
    })
    token.grantRole(token.MINTER_ROLE(), acct.address, {'from': acct})

    print("Does {} have default admin role?".format(acct.address))
    hasDefaultAdmin = token.hasRole(token.DEFAULT_ADMIN_ROLE(), acct.address)
    print(hasDefaultAdmin)

    print("Does {} have minter role?".format(acct.address))
    hasMinter = token.hasRole(token.MINTER_ROLE(), acct.address)
    print(hasMinter)

    # TODO: Deploy OVL faucet contract for alpha trading


    # TODO: Mint 10,000 of total 100,000 OVL to faucet


    # Deploy Chainlink BTCUSD feed && associated FPosition
    print("Chainlink addr: {}".format(chainlink_addrs['BTCUSD'][network]))
    feed_btcusd_chainlink = OVLChainlinkFeed.deploy(
        chainlink_addrs['BTCUSD'][network], # Kovan feed; TODO: debug issues with Kovan deploy
        {'from': acct}
    )
    print("Feed data source: {}".format(feed_btcusd_chainlink.dataSource()))

    position_btcusd_chainlink = OVLFPosition.deploy(
        "uri", token.address, feed_btcusd_chainlink.address,
        {'from': acct}
    )
    print("Position governance: {}".format(position_btcusd_chainlink.governance()))
    print("Position feed: {}".format(position_btcusd_chainlink.feed()))
    print("Position treasury: {}".format(position_btcusd_chainlink.treasury()))

    # Give position market the minter role
    token.grantRole(
        token.MINTER_ROLE(),
        position_btcusd_chainlink.address,
        {'from': acct}
    )
    print("Does {} have minter role?".format(acct.address))
    hasMinter = token.hasRole(
        token.MINTER_ROLE(),
        position_btcusd_chainlink.address
    )
    print(hasMinter)

    # TODO: Approve pos contract for X OVL tokens before build
