from brownie import OVLToken, OVLFPosition, OVLChainlinkFeed, OVLClaim, accounts
from brownie._config import CONFIG

chainlink_addrs = {
    "BTCUSD": {
        "mainnet": "0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c",
        "rinkeby": "0xECe365B379E1dD183B20fc5f022230C044d51404",
        "kovan": "0x6135b13325bfC4B00278B4abC5e20bbce2D6580e",
        "mainnet-fork": "0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c", # won't work on ganache-cli testnet
        "rounds": 8, # BTCUSD has 1 hr sampling on Rinkeby
    },
    "ETHUSD": {
        "mainnet": "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
        "rinkeby": "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e",
        "kovan": "0x9326BFA02ADD2366b30bacB125260Af641031331",
        "mainnet-fork": "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
        "rounds": 8, # ETHUSD has 20m sampling on Rinkeby
    },
    "DAIUSD": {
        "mainnet": "0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9",
        "rinkeby": "0x2bA49Aaa16E6afD2a993473cfB70Fa8559B523cF",
        "kovan": "0x777A68032a88E5A84678A77Af2CD65A7b3c0775a",
        "mainnet-fork": "0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9",
        "rounds": 8, # DAIUSD has 1h sampling on Rinkeby
    },
    "GAS": {
        "mainnet": "0x169E633A2D1E6c10dD91238Ba11c4A708dfEF37C",
        "rinkeby": "",
        "kovan": "",
        "mainnet-fork": "0x169E633A2D1E6c10dD91238Ba11c4A708dfEF37C",
        "rounds": 8, # Fast Gas/Gwei has 1h sampling on mainnet
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

    # Mint supply to treasury/gov and revoke minter role
    token.mint(100000*1e18, {'from': acct})
    token.revokeRole(token.MINTER_ROLE(), acct.address, {'from': acct})
    print("Token supply:", token.totalSupply())

    print("Does {} still have minter role?".format(acct.address))
    hasMinter = token.hasRole(token.MINTER_ROLE(), acct.address)
    print(hasMinter)

    # Deploy all the Chainlink feeds && associated FPosition markets
    for k, v in chainlink_addrs.items():
        print("Chainlink addr: {}".format(v[network]))
        if v[network] == "":
            continue

        feed = OVLChainlinkFeed.deploy(
            v[network],
            v["rounds"],
            {'from': acct}
        )
        print("Feed data source: {}".format(feed.dataSource()))

        uri = "https://overlay.exchange/api/ovlfposition/{}".format(k)
        uri = uri + "/{id}.json" # TODO: Fix this formatting on deploy ...
        fpos = OVLFPosition.deploy(uri, token.address, feed.address,
            {'from': acct}
        )
        print("OVLFPosition uri ({}): {}".format(k, fpos.uri(0)))
        print("OVLFPosition governance ({}): {}".format(k, fpos.governance()))
        print("OVLFPosition feed ({}): {}".format(k, fpos.feed()))
        print("OVLFPosition treasury ({}): {}".format(k, fpos.treasury()))

        # Give position market the minter role
        token.grantRole(
            token.MINTER_ROLE(),
            fpos.address,
            {'from': acct}
        )
        print("Does {} have minter role?".format(acct.address))
        hasMinter = token.hasRole(
            token.MINTER_ROLE(),
            fpos.address
        )
        print(hasMinter)


    # Deploy OVL faucet contract for alpha trading
    claim = OVLClaim.deploy(token.address, 100*1e18, {'from': acct})

    # Transfer 10,000 of total 100,000 OVL to faucet (90,000 for liq mining)
    token.transfer(claim.address, 10000*1e18, {'from': acct})
    print("OVLClaim balance:", token.balanceOf(claim.address))
    print("Gov balance", token.balanceOf(acct.address))

    # TODO: On deploy, upload uri related info
