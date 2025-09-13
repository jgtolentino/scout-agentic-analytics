import { fromVendor, VendorTokens, ScoutTokens } from './adapter'
import vendorJson from './tokens.json'

export const TOKENS: ScoutTokens = fromVendor(vendorJson as VendorTokens)