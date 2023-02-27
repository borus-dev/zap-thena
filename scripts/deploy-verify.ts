import { ethers, run, network } from 'hardhat';

async function main() {
    const ZapThena = await ethers.getContractFactory('ZapThena');

    const zapThena = await ZapThena.deploy();
    console.log('Deploying ZapThena...');
    await zapThena.deployed();
    console.log('ZapThena deployed to:', zapThena.address);

    if (network.config.chainId === 56 && process.env.ETHERSCAN_API) {
        console.log('Waiting for block confirmations...');
        await zapThena.deployTransaction.wait(5);
        await verify(zapThena.address, []);
    }
}

const verify = async (contractAddress: string, args: any) => {
    console.log('Verifying contract...');
    try {
        await run('verify:verify', {
            address: contractAddress,
            constructorArguments: args,
        });
    } catch (e: any) {
        if (e.message.toLowerCase().includes('already verified')) {
            console.log('Already Verified!');
        } else {
            console.log(e);
        }
    }
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
