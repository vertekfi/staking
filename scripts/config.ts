interface Addresses {
  zeroAddress: string;
  deployer: string;
  vtek: string;
  aceLab: string;
  roar: string;
  gasPrice: string;
  scanner: string;
}

export const contractNameMapper = {
  aceLab: 'AceLab',
};

const config: Addresses = {
  zeroAddress: '0x0000000000000000000000000000000000000000',

  deployer: '0xe9a274F0153c9D24a6C081465e0641ff0bBD0286',
  vtek: '0xeD236c32f695c83Efde232c288701d6f9C23E60E',
  // aceLab: '0xDBC838Ee888407815889d5603bc679A81715F928',
  aceLab: '0x77B7157de21bEB852500726161575b4C197Faf0E',

  roar: '0xE9Fb60609582D3812B0Af7520D66c32b9dbFCb98',
  scanner: 'https://bscscan.com/address/',
  gasPrice: '', // for gasThrottler
};

export default config;