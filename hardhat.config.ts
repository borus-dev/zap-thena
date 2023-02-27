import 'dotenv/config';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-etherscan';
import '@nomicfoundation/hardhat-chai-matchers';
import 'hardhat-gas-reporter';
import 'hardhat-abi-exporter';
import 'hardhat-contract-sizer';
// import 'solidity-coverage';

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: {
        version: '0.8.14',
        settings: {
            optimizer: {
                enabled: true,
                runs: 1000,
            },
            evmVersion: 'london',
        },
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_API,
    },
    mocha: {
        timeout: 6000000,
    },
    abiExporter: {
        path: './abi',
        clear: true,
        flat: true,
        spacing: 2,
        pretty: true,
    },
    networks: {
        hardhat: {
            allowUnlimitedContractSize: true,
            chainId: 1,
            hardfork: 'london',
            forking: {
                url: `https://mainnet.infura.io/v3/${process.env.INFURA_ID}`,
            },
            // initialBaseFeePerGas: 0,
            mining: {
                auto: true,
                interval: 1000,
            },
        },
        localhost: {
            chainId: 1,
            url: 'http://127.0.0.1:8545/',
            allowUnlimitedContractSize: true,
            timeout: 1000 * 60,
        },
        'polygon-mumbai': {
            url: 'https://polygon-rpc.com',
            chainId: 137,
            hardfork: 'istanbul',
            accounts: [process.env.ACCOUNT],
        },
        rinkeby: {
            url: `https://rinkeby.infura.io/v3/${process.env.INFURA_ID}`,
            chainId: 4,
            hardfork: 'istanbul',
            accounts: [process.env.ACCOUNT],
        },
        goerli: {
            url: `https://goerli.infura.io/v3/${process.env.INFURA_ID}`,
            chainId: 5,
            hardfork: 'london',
            accounts: [process.env.ACCOUNT],
            // gas: 10000000,  // tx gas limit
            // blockGasLimit: 150000000,
            gasPrice: 10000000000, // 10 Gwei
        },
        mainnet: {
            url: `https://mainnet.infura.io/v3/${process.env.INFURA_ID}`,
            chainId: 1,
            hardfork: 'london',
            accounts: [process.env.ACCOUNT],
            // gas: 10000000,  // tx gas limit
            // blockGasLimit: 150000000,
            // gasPrice: 15000000000, // 15 Gwei
        },
        bsc: {
            chainId: 56,
            hardfork: 'london',
            url: 'https://bsc-dataseed1.binance.org',
        },
    },
    gasReporter: {
        enabled: false,
    },
    contractSizer: {
        alphaSort: true,
        disambiguatePaths: false,
        runOnCompile: false,
        strict: true,
        only: [],
    },
};
