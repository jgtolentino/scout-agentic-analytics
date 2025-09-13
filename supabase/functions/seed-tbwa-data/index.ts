import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// TBWA Client Product Portfolio
const TBWA_PRODUCTS = {
  'Alaska Milk Corporation': {
    category: 'Dairy',
    products: [
      { sku: 'ALSK-EVAP-370', name: 'Alaska Evaporada 370ml', price: 35, weight: 1.2 },
      { sku: 'ALSK-COND-300', name: 'Alaska Condensada 300ml', price: 32, weight: 1.0 },
      { sku: 'ALSK-PWD-160', name: 'Alaska Fortified Powdered Milk 160g', price: 48, weight: 0.8 },
      { sku: 'ALSK-PWD-320', name: 'Alaska Fortified Powdered Milk 320g', price: 92, weight: 1.5 },
      { sku: 'ALSK-PWD-700', name: 'Alaska Fortified Powdered Milk 700g', price: 195, weight: 2.0 },
      { sku: 'ALSK-SWCR-300', name: 'Alaska Sweetened Condensed Creamer 300ml', price: 28, weight: 0.9 },
      { sku: 'ALSK-CLEV-370', name: 'Alaska Classic Evaporated Filled Milk 370ml', price: 30, weight: 1.1 },
      { sku: 'ALSK-FRSH-1L', name: 'Alaska Fresh Milk 1L', price: 95, weight: 1.8 },
      { sku: 'ALSK-UHT-250', name: 'Alaska UHT Fresh Milk 250ml', price: 25, weight: 0.5 }
    ]
  },
  'Del Monte Philippines': {
    category: 'Food',
    products: [
      { sku: 'DM-FSSAUCE-250', name: 'Del Monte Filipino Style Spaghetti Sauce 250g', price: 22, weight: 1.0 },
      { sku: 'DM-FSSAUCE-1K', name: 'Del Monte Filipino Style Spaghetti Sauce 1kg', price: 72, weight: 2.5 },
      { sku: 'DM-ITSAUCE-250', name: 'Del Monte Italian Style Spaghetti Sauce 250g', price: 25, weight: 1.0 },
      { sku: 'DM-ITSAUCE-1K', name: 'Del Monte Italian Style Spaghetti Sauce 1kg', price: 78, weight: 2.5 },
      { sku: 'DM-TOMSAUCE-200', name: 'Del Monte Tomato Sauce 200g', price: 18, weight: 0.8 },
      { sku: 'DM-TOMPASTE-150', name: 'Del Monte Tomato Paste 150g', price: 28, weight: 0.6 },
      { sku: 'DM-PJUICE-240', name: 'Del Monte Pineapple Juice Can 240ml', price: 20, weight: 0.7 },
      { sku: 'DM-PJUICE-1L', name: 'Del Monte Pineapple Juice Tetra 1L', price: 65, weight: 1.5 },
      { sku: 'DM-4SJUICE-1L', name: 'Del Monte Four Seasons Juice 1L', price: 70, weight: 1.5 },
      { sku: 'DM-PJLIGHT-1L', name: 'Del Monte Pineapple Juice Light 1L', price: 68, weight: 1.5 },
      { sku: 'DM-PCRUSH-432', name: 'Del Monte Crushed Pineapple 432g', price: 45, weight: 1.2 },
      { sku: 'DM-PCHUNK-560', name: 'Del Monte Pineapple Chunks 560g', price: 55, weight: 1.5 },
      { sku: 'DM-PSLICE-825', name: 'Del Monte Sliced Pineapple 825g', price: 85, weight: 2.0 },
      { sku: 'DM-KETCHUP-320', name: 'Del Monte Original Ketchup 320g', price: 32, weight: 0.8 },
      { sku: 'DM-HOTKETCH-320', name: 'Del Monte Hot & Spicy Ketchup 320g', price: 35, weight: 0.8 }
    ]
  },
  'Peerless Products': {
    category: 'Personal Care',
    products: [
      { sku: 'CHMP-BAR-380', name: 'Champion Bar Regular 380g', price: 25, weight: 0.5 },
      { sku: 'CHMP-PWD-500', name: 'Champion Detergent Powder 500g', price: 38, weight: 1.0 },
      { sku: 'CHMP-PWD-1K', name: 'Champion Detergent Powder 1kg', price: 72, weight: 1.8 },
      { sku: 'CHMP-FAB-500', name: 'Champion FabCon Classic Blue 500ml', price: 42, weight: 0.8 },
      { sku: 'CALLA-PWD-2.4K', name: 'Calla Detergent Powder Floral 2.4kg', price: 145, weight: 3.0 },
      { sku: 'CALLA-PWD-1.5K', name: 'Calla Detergent Powder Classic 1.5kg', price: 95, weight: 2.0 },
      { sku: 'SYS-TPASTE-150', name: 'Systema Toothpaste Cool Mint 150g', price: 85, weight: 0.3 },
      { sku: 'SYS-TBRUSH-SOFT', name: 'Systema Toothbrush Soft', price: 65, weight: 0.1 },
      { sku: 'SYS-MWASH-250', name: 'Systema Mouthwash Green Mint 250ml', price: 120, weight: 0.4 },
      { sku: 'HANA-SHMP-180', name: 'Hana Shampoo Coconut Cream 180ml', price: 42, weight: 0.3 },
      { sku: 'HANA-COND-180', name: 'Hana Conditioner Strawberry 180ml', price: 42, weight: 0.3 },
      { sku: 'HANA-ANTID-340', name: 'Hana Shampoo Anti-Dandruff 340ml', price: 75, weight: 0.5 }
    ]
  },
  'Oishi': {
    category: 'Snacks',
    products: [
      { sku: 'OSH-PRAWN-24', name: 'Oishi Prawn Crackers 24g', price: 8, weight: 0.1 },
      { sku: 'OSH-PRAWN-60', name: 'Oishi Prawn Crackers 60g', price: 20, weight: 0.2 },
      { sku: 'MARTY-PLAIN-90', name: "Marty's Cracklin' Plain Salted 90g", price: 25, weight: 0.3 },
      { sku: 'MARTY-SPICY-90', name: "Marty's Cracklin' Spicy Vinegar 90g", price: 25, weight: 0.3 },
      { sku: 'OSH-RIDG-CH-65', name: 'Oishi Ridges Cheese 65g', price: 22, weight: 0.2 },
      { sku: 'OSH-RIDG-SC-65', name: 'Oishi Ridges Sour Cream 65g', price: 22, weight: 0.2 },
      { sku: 'OSH-PILL-48', name: 'Oishi Pillows Choco-Filled 48g', price: 15, weight: 0.15 },
      { sku: 'BREAD-PAN-45', name: 'Bread Pan Cheese & Garlic 45g', price: 12, weight: 0.1 },
      { sku: 'OSH-WAFU-VAN-30', name: 'Oishi Wafu Creamy Vanilla 30g', price: 10, weight: 0.08 },
      { sku: 'OSH-WAFU-CHO-30', name: 'Oishi Wafu Choco 30g', price: 10, weight: 0.08 }
    ]
  },
  'JTI Philippines': {
    category: 'Tobacco',
    products: [
      { sku: 'WIN-RED-20S', name: 'Winston Red Soft Pack 20s', price: 145, weight: 0.5 },
      { sku: 'WIN-BLUE-20S', name: 'Winston Blue Soft Pack 20s', price: 145, weight: 0.5 },
      { sku: 'MEV-MENTH-LT', name: 'Mevius Menthol Lights', price: 155, weight: 0.5 },
      { sku: 'MEV-ORIG-BLU', name: 'Mevius Original Blue', price: 155, weight: 0.5 },
      { sku: 'CAM-ACT-MINT', name: 'Camel Activate Mint Capsule', price: 150, weight: 0.5 },
      { sku: 'CAM-NONFILT', name: 'Camel Non-Filter', price: 160, weight: 0.5 },
      { sku: 'MIGHTY-RED', name: 'Mighty Full Flavor Red', price: 110, weight: 0.4 },
      { sku: 'MIGHTY-MENTH', name: 'Mighty Menthol Green', price: 110, weight: 0.4 }
    ]
  }
}

// Competitor products for realistic market share
const COMPETITOR_PRODUCTS = {
  'Nestle': {
    category: 'Dairy',
    products: [
      { sku: 'BEAR-MILK-300', name: 'Bear Brand Milk 300ml', price: 38, weight: 1.0 },
      { sku: 'NIDO-PWD-700', name: 'Nido Fortified 700g', price: 210, weight: 2.0 }
    ]
  },
  'Coca-Cola': {
    category: 'Beverages',
    products: [
      { sku: 'COKE-REG-1.5L', name: 'Coca-Cola Regular 1.5L', price: 65, weight: 1.8 },
      { sku: 'SPRITE-1L', name: 'Sprite 1L', price: 45, weight: 1.2 }
    ]
  },
  'Unilever': {
    category: 'Personal Care',
    products: [
      { sku: 'SURF-PWD-1K', name: 'Surf Powder 1kg', price: 85, weight: 1.5 },
      { sku: 'CLOSE-UP-150', name: 'Close Up Toothpaste 150g', price: 75, weight: 0.3 }
    ]
  },
  'Jack n Jill': {
    category: 'Snacks',
    products: [
      { sku: 'NOVA-MULTI-78', name: 'Nova Multigrain 78g', price: 25, weight: 0.2 },
      { sku: 'PIATTOS-CH-85', name: 'Piattos Cheese 85g', price: 30, weight: 0.25 }
    ]
  },
  'Philip Morris': {
    category: 'Tobacco',
    products: [
      { sku: 'MARL-RED-20S', name: 'Marlboro Red 20s', price: 160, weight: 0.5 },
      { sku: 'MARL-GOLD-20S', name: 'Marlboro Gold 20s', price: 160, weight: 0.5 }
    ]
  }
}

// Philippine regions and cities
const PH_REGIONS = [
  { region: 'NCR', cities: ['Manila', 'Quezon City', 'Makati', 'Taguig', 'Pasig', 'Paranaque', 'Caloocan', 'Marikina'] },
  { region: 'Region I', cities: ['Dagupan', 'San Fernando LU', 'Vigan', 'Laoag', 'Batac', 'Alaminos'] },
  { region: 'Region II', cities: ['Tuguegarao', 'Santiago', 'Cauayan', 'Ilagan'] },
  { region: 'Region III', cities: ['Angeles', 'San Fernando PAM', 'Olongapo', 'Balanga', 'Malolos', 'Cabanatuan'] },
  { region: 'Region IV-A', cities: ['Batangas City', 'Lipa', 'Lucena', 'Antipolo', 'Dasmarinas', 'Bacoor'] },
  { region: 'Region IV-B', cities: ['Puerto Princesa', 'Calapan', 'Mamburao'] },
  { region: 'Region V', cities: ['Naga', 'Legazpi', 'Iriga', 'Sorsogon City', 'Masbate City'] },
  { region: 'Region VI', cities: ['Iloilo City', 'Bacolod', 'Roxas', 'Kalibo'] },
  { region: 'Region VII', cities: ['Cebu City', 'Mandaue', 'Lapu-Lapu', 'Tagbilaran', 'Dumaguete'] },
  { region: 'Region VIII', cities: ['Tacloban', 'Ormoc', 'Catbalogan', 'Calbayog', 'Maasin'] },
  { region: 'Region IX', cities: ['Zamboanga City', 'Pagadian', 'Dipolog', 'Dapitan'] },
  { region: 'Region X', cities: ['Cagayan de Oro', 'Iligan', 'Malaybalay', 'Valencia', 'Oroquieta'] },
  { region: 'Region XI', cities: ['Davao City', 'Tagum', 'Panabo', 'Digos', 'Mati'] },
  { region: 'Region XII', cities: ['General Santos', 'Koronadal', 'Tacurong', 'Kidapawan'] },
  { region: 'Region XIII', cities: ['Butuan', 'Surigao City', 'Bislig', 'Bayugan', 'Tandag'] },
  { region: 'CAR', cities: ['Baguio', 'Tabuk'] },
  { region: 'BARMM', cities: ['Cotabato City', 'Lamitan', 'Marawi'] }
]

const STORE_TYPES = ['urban_high', 'urban_medium', 'residential', 'rural']
const ECONOMIC_CLASSES = ['A', 'B', 'C', 'D', 'E']
const TIME_OF_DAY = ['morning', 'afternoon', 'evening', 'night']
const GENDERS = ['male', 'female']
const AGE_BRACKETS = ['18-24', '25-34', '35-44', '45-54', '55+']
const PAYMENT_METHODS = ['cash', 'gcash', 'maya', 'credit']
const CUSTOMER_TYPES = ['regular', 'occasional', 'new']

serve(async (req) => {
  try {
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const { num_transactions = 10000, start_date = '2025-01-01', end_date = '2025-08-02' } = await req.json()

    // Generate stores across regions
    const stores = []
    let storeId = 1
    for (const region of PH_REGIONS) {
      for (const city of region.cities) {
        for (const storeType of STORE_TYPES) {
          stores.push({
            id: `STORE-${storeId.toString().padStart(5, '0')}`,
            region: region.region,
            city: city,
            store_type: storeType
          })
          storeId++
        }
      }
    }

    // Flatten all products with brand info
    const allTBWAProducts = []
    const allCompetitorProducts = []
    
    for (const [brand, data] of Object.entries(TBWA_PRODUCTS)) {
      for (const product of data.products) {
        allTBWAProducts.push({ ...product, brand, category: data.category, is_tbwa: true })
      }
    }
    
    for (const [brand, data] of Object.entries(COMPETITOR_PRODUCTS)) {
      for (const product of data.products) {
        allCompetitorProducts.push({ ...product, brand, category: data.category, is_tbwa: false })
      }
    }

    // Generate transactions with market share targets
    const transactions = []
    const startTime = new Date(start_date).getTime()
    const endTime = new Date(end_date).getTime()
    
    // Calculate FMCG vs Tobacco split (80/20 typical)
    const fmcgTransactions = Math.floor(num_transactions * 0.8)
    const tobaccoTransactions = num_transactions - fmcgTransactions
    
    // Target market shares
    const TBWA_FMCG_SHARE = 0.19 // 19%
    const JTI_TOBACCO_SHARE = 0.39 // 39%

    // Generate FMCG transactions
    for (let i = 0; i < fmcgTransactions; i++) {
      const store = stores[Math.floor(Math.random() * stores.length)]
      const isTBWA = Math.random() < TBWA_FMCG_SHARE
      
      const fmcgTBWA = allTBWAProducts.filter(p => p.category !== 'Tobacco')
      const fmcgCompetitor = allCompetitorProducts.filter(p => p.category !== 'Tobacco')
      
      const product = isTBWA 
        ? fmcgTBWA[Math.floor(Math.random() * fmcgTBWA.length)]
        : fmcgCompetitor[Math.floor(Math.random() * fmcgCompetitor.length)]
      
      const timestamp = new Date(startTime + Math.random() * (endTime - startTime))
      const hour = timestamp.getHours()
      let timeOfDay = 'morning'
      if (hour >= 12 && hour < 17) timeOfDay = 'afternoon'
      else if (hour >= 17 && hour < 20) timeOfDay = 'evening'
      else if (hour >= 20) timeOfDay = 'night'
      
      const quantity = Math.ceil(Math.random() * 3)
      const basketSize = Math.ceil(Math.random() * 5) + 1
      
      transactions.push({
        id: `TXN-${Date.now()}-${i}`,
        store_id: store.id,
        timestamp: timestamp.toISOString(),
        time_of_day: timeOfDay,
        location_region: store.region,
        location_city: store.city,
        location_barangay: `Brgy_${Math.ceil(Math.random() * 50)}`,
        product_category: product.category,
        brand_name: product.brand,
        sku: product.sku,
        units_per_transaction: quantity,
        peso_value: product.price * quantity,
        basket_size: basketSize,
        gender: GENDERS[Math.floor(Math.random() * GENDERS.length)],
        age_bracket: AGE_BRACKETS[Math.floor(Math.random() * AGE_BRACKETS.length)],
        payment_method: PAYMENT_METHODS[Math.floor(Math.random() * PAYMENT_METHODS.length)],
        customer_type: CUSTOMER_TYPES[Math.floor(Math.random() * CUSTOMER_TYPES.length)],
        store_type: store.store_type,
        economic_class: ECONOMIC_CLASSES[Math.floor(Math.random() * ECONOMIC_CLASSES.length)],
        campaign_influenced: Math.random() < 0.25,
        handshake_score: 0.5 + Math.random() * 0.5,
        is_tbwa_client: product.is_tbwa || false,
        substitution_occurred: Math.random() < 0.1,
        substitution_reason: Math.random() < 0.1 ? 'stockout' : null
      })
    }

    // Generate tobacco transactions
    for (let i = 0; i < tobaccoTransactions; i++) {
      const store = stores[Math.floor(Math.random() * stores.length)]
      const isJTI = Math.random() < JTI_TOBACCO_SHARE
      
      const tobaccoTBWA = allTBWAProducts.filter(p => p.category === 'Tobacco')
      const tobaccoCompetitor = allCompetitorProducts.filter(p => p.category === 'Tobacco')
      
      const product = isJTI 
        ? tobaccoTBWA[Math.floor(Math.random() * tobaccoTBWA.length)]
        : tobaccoCompetitor[Math.floor(Math.random() * tobaccoCompetitor.length)]
      
      const timestamp = new Date(startTime + Math.random() * (endTime - startTime))
      const hour = timestamp.getHours()
      let timeOfDay = 'morning'
      if (hour >= 12 && hour < 17) timeOfDay = 'afternoon'
      else if (hour >= 17 && hour < 20) timeOfDay = 'evening'
      else if (hour >= 20) timeOfDay = 'night'
      
      transactions.push({
        id: `TXN-${Date.now()}-${fmcgTransactions + i}`,
        store_id: store.id,
        timestamp: timestamp.toISOString(),
        time_of_day: timeOfDay,
        location_region: store.region,
        location_city: store.city,
        location_barangay: `Brgy_${Math.ceil(Math.random() * 50)}`,
        product_category: 'Tobacco',
        brand_name: product.brand,
        sku: product.sku,
        units_per_transaction: 1,
        peso_value: product.price,
        basket_size: Math.ceil(Math.random() * 3),
        gender: Math.random() < 0.8 ? 'male' : 'female', // Tobacco skews male
        age_bracket: AGE_BRACKETS[Math.floor(Math.random() * AGE_BRACKETS.length)],
        payment_method: PAYMENT_METHODS[Math.floor(Math.random() * PAYMENT_METHODS.length)],
        customer_type: CUSTOMER_TYPES[Math.floor(Math.random() * CUSTOMER_TYPES.length)],
        store_type: store.store_type,
        economic_class: ECONOMIC_CLASSES[Math.floor(Math.random() * ECONOMIC_CLASSES.length)],
        campaign_influenced: Math.random() < 0.15,
        handshake_score: 0.6 + Math.random() * 0.4,
        is_tbwa_client: product.brand === 'JTI Philippines',
        substitution_occurred: Math.random() < 0.05,
        substitution_reason: Math.random() < 0.05 ? 'brand_preference' : null
      })
    }

    // Insert in batches
    const batchSize = 1000
    let totalInserted = 0
    
    for (let i = 0; i < transactions.length; i += batchSize) {
      const batch = transactions.slice(i, i + batchSize)
      const { error } = await supabase
        .from('scout_transactions')
        .insert(batch)
      
      if (error) throw error
      totalInserted += batch.length
    }

    // Calculate actual market shares
    const fmcgTBWACount = transactions.filter(t => t.is_tbwa_client && t.product_category !== 'Tobacco').length
    const tobaccoJTICount = transactions.filter(t => t.is_tbwa_client && t.product_category === 'Tobacco').length
    
    const actualFMCGShare = (fmcgTBWACount / fmcgTransactions * 100).toFixed(1)
    const actualTobaccoShare = (tobaccoJTICount / tobaccoTransactions * 100).toFixed(1)

    return new Response(JSON.stringify({
      success: true,
      summary: {
        total_transactions: totalInserted,
        fmcg_transactions: fmcgTransactions,
        tobacco_transactions: tobaccoTransactions,
        tbwa_fmcg_share: `${actualFMCGShare}%`,
        jti_tobacco_share: `${actualTobaccoShare}%`,
        regions_covered: PH_REGIONS.length,
        stores_generated: stores.length,
        date_range: { start: start_date, end: end_date }
      }
    }), {
      headers: { 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    return new Response(JSON.stringify({ 
      success: false, 
      error: error.message 
    }), { 
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})