/// Localized UI strings for UsizoAI.
///
/// Keys use a flat dot-notation: `'screen.section.key'`.
/// Language codes: `en` (English), `sn` (Shona), `nd` (Ndebele).
const Map<String, Map<String, String>> appStrings = {
  // ── Symptom Checker ───────────────────────────────────────────────
  'checker.subtitle': {
    'en': 'Private, practical health guidance — even when you are offline.',
    'sn': 'Nzira yekurwara inounya — kunyange uchiri offline.',
    'nd': 'Indlela yokunakekela impilo — naseningeni.',
  },
  'checker.howAreYou': {
    'en': 'How are you feeling?',
    'sn': 'Wakadii here?',
    'nd': 'Ujani?',
  },
  'checker.hint': {
    'en': 'Example: I have a mild headache since this morning...',
    'sn': 'Muenzaniso: Munhu wangu unouraya mwoyo kubva mangwanani...',
    'nd': 'Isibonelo: Ngisephithelelwe yindloko kusukela ekuseni...',
  },
  'checker.chipHeadache': {
    'en': 'Headache',
    'sn': 'Chirwere chemwoyo',
    'nd': 'Ubuhlungu bentloko',
  },
  'checker.chipCough': {
    'en': 'Cough',
    'sn': 'Kufema',
    'nd': 'Ukuqhafaza',
  },
  'checker.chipNausea': {
    'en': 'Nausea',
    'sn': 'Kudziya muromo',
    'nd': 'Isicanuco',
  },
  'checker.chipItchySkin': {
    'en': 'Itchy skin',
    'sn': 'Gutsa muviri',
    'nd': 'Ubulukhuno besikhumba',
  },
  'checker.analyzing': {
    'en': 'Analyzing...',
    'sn': 'Kuongorora...',
    'nd': 'Kuhlola...',
  },
  'checker.checkSymptoms': {
    'en': 'Check symptoms',
    'sn': 'Tarisa zvirwere',
    'nd': 'Bheka izimpawu',
  },
  'checker.freeChecksRemaining': {
    'en': 'free checks remaining',
    'sn': 'matarisiro aya ari kusara',
    'nd': 'izibheko ezisele',
  },
  'checker.unlimitedChecks': {
    'en': 'Unlimited checks with Plus',
    'sn': 'Matarisiro asina muganhu nePlus',
    'nd': 'Izibheko ezingenamkhawulo nePlus',
  },
  'checker.yourGuidance': {
    'en': 'Your guidance',
    'sn': 'Nzira yako',
    'nd': 'Isiqondiso sakho',
  },
  'checker.confidence': {
    'en': 'Pattern match confidence',
    'sn': 'Kuvimba kwekufanana',
    'nd': 'Imininingwane yokufanana',
  },
  'checker.resultDisclaimer': {
    'en': 'Rest, hydrate, and monitor your symptoms. This result is not a medical diagnosis.',
    'sn': 'Zorora, nhuga, uye utarise zvirwere zvako. Izvi hazvisi kurwara.',
    'nd': 'Phumula, phuza amanzi, ubheke izimpawu zakho. Lokhu akulona ukuxilongwa.',
  },
  'checker.noMatch': {
    'en': 'No match found. Try describing another symptom, or consult a healthcare professional.',
    'sn': 'Hapana chimwe chakafanana. Ededzera chirwere chimwe, kana kubvunza chipiropa.',
    'nd': 'Akukho lutho olufanayo. Zama ukuchaza enye inkinga, noma ubuze udokotela.',
  },
  'checker.helpfulOptions': {
    'en': 'Helpful options',
    'sn': 'Sarudzo dzinobatsira',
    'nd': 'Izinketho ezisizayo',
  },
  'checker.upgradeTitle': {
    'en': 'Free checks used',
    'sn': 'Matarisiro emahara akariswa',
    'nd': 'Izibheko zamahhala zisetshenzisiwe',
  },
  'checker.upgradeBody': {
    'en': 'You have used your three free checks. Upgrade to Plus for unlimited offline checks.',
    'sn': 'Washandisa matarisiro ako matatu emahara. Kwidziridza kuPlus kuti uwane matarisiro asina muganhu.',
    'nd': 'Usebenzise izibheko zakho ezi-3 zamahhala. Thola i-Plus ukuze ube nezibheko ezingenamkhawulo.',
  },
  'checker.notNow': {
    'en': 'Not now',
    'sn': 'Kwete izvozvi',
    'nd': 'Hayi manje',
  },
  'checker.upgradeToPlus': {
    'en': 'Upgrade to Plus',
    'sn': 'Kwidziridza kuPlus',
    'nd': 'Thola i-Plus',
  },
  'checker.describeSymptom': {
    'en': 'Describe at least one symptom.',
    'sn': 'Tsanangura chirwere chimwe chese.',
    'nd': 'Chaza okungenani isipawu esisodwa.',
  },
  // ── Home / Navigation ─────────────────────────────────────────────
  'nav.check': {
    'en': 'Check',
    'sn': 'Tarisa',
    'nd': 'Bheka',
  },
  'nav.market': {
    'en': 'Market',
    'sn': 'Mugadziriro',
    'nd': 'Imakethe',
  },
  'nav.profile': {
    'en': 'Profile',
    'sn': 'Mamiriro',
    'nd': 'Iphrofayili',
  },
  // ── Marketplace ───────────────────────────────────────────────────
  'market.title': {
    'en': 'Wellness market',
    'sn': 'Mugadziriro yehupenyu',
    'nd': 'Imakethe yokuphila',
  },
  'market.myShop': {
    'en': 'My shop',
    'sn': 'Shoko yangu',
    'nd': 'Ishophi yami',
  },
  'market.sellOnUsizo': {
    'en': 'Sell on UsizoAI',
    'sn': 'Tengesa paUsizoAI',
    'nd': 'Thengisa ku-UsizoAI',
  },
  'market.viewCart': {
    'en': 'View cart',
    'sn': 'Tarisa kadhi',
    'nd': 'Bheka ikhadi',
  },
  'market.online': {
    'en': 'Online',
    'sn': 'PaIneti',
    'nd': 'Ku-inthanethi',
  },
  'market.offline': {
    'en': 'Offline',
    'sn': 'Kunze kweIneti',
    'nd': 'Ngaphandle kwe-inthanethi',
  },
  'market.shopOnline': {
    'en': 'Shop herbal products from trusted local vendors.',
    'sn': 'Tenga zvinhu zvechiremedzi kubva kune vatengesi vekumugadziriro.',
    'nd': 'Thenga izinto zokwelapha kubuya kubathengisi besifunda.',
  },
  'market.shopOffline': {
    'en': "You're offline. Contact vendors directly when ready to buy.",
    'sn': 'Uri kunze kweIneti. Batanai nevatengesi muffumbiro.',
    'nd': 'Ungaphandle kwe-inthanethi. Xhumana nabathengisi uma ukulungele ukuthenga.',
  },
  'market.searchProducts': {
    'en': 'Search products',
    'sn': 'Tsvaga zvinhu',
    'nd': 'Sesha izinto',
  },
  'market.locationUnavailable': {
    'en': 'Location unavailable',
    'sn': 'Nzvimbo hairipo',
    'nd': 'Indawo ayitholakali',
  },
  'market.enableLocation': {
    'en': 'Enable location to see nearby vendors.',
    'sn': 'Vhura nzvimbo kuona vatengesi vadiki.',
    'nd': 'Vumela indawo ukuze ubone abathengisi abaseduze.',
  },
  'market.retry': {
    'en': 'Retry',
    'sn': 'Ededza zvakare',
    'nd': 'Phinda uzame',
  },
  'market.nearbyVendors': {
    'en': 'Showing vendors near you',
    'sn': 'Kuratidza vatengesi padivi regako',
    'nd': 'Kubonisa abathengisi abaseduze nawe',
  },
  'market.sortedByDistance': {
    'en': 'Sorted by distance from your current location',
    'sn': 'Yakarongwa nedumbo kubva panzvimbo yako',
    'nd': 'Hlelwe ngokusekelwa endaweni yakho',
  },
  'market.noProducts': {
    'en': 'No products found. Try a different search.',
    'sn': 'Hapana zvinhu. Ededzera kutsvakurudza kwakasiyana.',
    'nd': 'Akukho izinto ezitholiwe. Zama ukusesha okunye.',
  },
  'market.vendorsNearYou': {
    'en': 'Vendors near you',
    'sn': 'Vatengesi padivi regako',
    'nd': 'Abathengisi abaseduze nawe',
  },
  'market.ourVendors': {
    'en': 'Our vendors',
    'sn': 'Vatengesi vedu',
    'nd': 'Abathengisi bethu',
  },
  'market.safetyFirst': {
    'en':
        'Safety first\n\nUsizoAI does not replace a qualified healthcare professional. Never delay emergency care based on an app suggestion.',
    'sn':
        'Kuchenjedza kwekutanga\n\nUsizoAI hairisi chipiropa chakarurama. Usambotambudza rubatsiro rwechiremera.',
    'nd':
        'Ukuphepha kuqala\n\nI-UsizoAI ayishintshi udokotela oqeqeshiwe. Ungalibazisi usizo lwengcuphe ngeseluleko ye-app.',
  },
  'market.disclaimer': {
    'en': 'UsizoAI is not a replacement for professional medical care. Always consult a doctor for serious conditions.',
    'sn': 'UsizoAI hairisi kurwara. Tevergachipiropa nguva yose.',
    'nd': 'I-UsizoAI ayiyona indlela yokunakekela abagula. Ngaso sonke isikhathi buza udokotela.',
  },
  'market.outOfStock': {
    'en': 'Out of stock',
    'sn': 'Hazvisati',
    'nd': 'Akusekho',
  },
  'market.addToCart': {
    'en': 'Add to cart',
    'sn': 'Wedzera kuKadhi',
    'nd': 'Engeza eKhadini',
  },
  'market.inCartRemove': {
    'en': 'In cart — remove',
    'sn': 'MuKadhi — chenesa',
    'nd': 'Ekhadini — susa',
  },
  'market.buyNow': {
    'en': 'Start EcoCash order',
    'sn': 'Tanga odha yeEcoCash',
    'nd': 'Qalisa i-oda yeEcoCash',
  },
  'market.contactOnWhatsApp': {
    'en': 'Contact on WhatsApp',
    'sn': 'Batanai paWhatsApp',
    'nd': 'Xhumana nge-WhatsApp',
  },
  'market.contactVendor': {
    'en': 'Contact',
    'sn': 'Batanai',
    'nd': 'Xhumana',
  },
  'market.addedToCart': {
    'en': 'added to cart',
    'sn': 'yakawedzerwa kuKadhi',
    'nd': 'engeziwe eKhadini',
  },
  'market.noContact': {
    'en': 'No contact number available for this vendor.',
    'sn': 'Hapana nhamburo yekubatana pane uyu mutengesi.',
    'nd': 'Akukho nombolo yokuxhumana etholakalayo kulowo mthengisi.',
  },
  'market.outOfStockContact': {
    'en': 'Out of stock — contact',
    'sn': 'Hazvisati — batanai',
    'nd': 'Akusekho — xhumana',
  },
  // ── Profile ───────────────────────────────────────────────────────
  'profile.title': {
    'en': 'Your profile',
    'sn': 'Mamiriro ako',
    'nd': 'Iphrofayili yakho',
  },
  'profile.staysOnDevice': {
    'en': 'Your information stays on this device.',
    'sn': 'Ruzivo rwofojhiri pane iyi device.',
    'nd': 'Ulwazi lwakho luhlala kule device.',
  },
  'profile.name': {
    'en': 'Name',
    'sn': 'Zita',
    'nd': 'Igama',
  },
  'profile.emailOptional': {
    'en': 'Email (optional)',
    'sn': 'Email (kunyangwe)',
    'nd': 'I-email (ngokuzithandela)',
  },
  'profile.allergies': {
    'en': 'Allergies or sensitivities',
    'sn': 'Zvirwere kana kunzwa',
    'nd': 'Izilwelwe noma ubuhlungu',
  },
  'profile.emergencyContact': {
    'en': 'Emergency contact',
    'sn': 'Nhamburo yechiremera',
    'nd': 'Inombolo yokuxhumana ngephutha',
  },
  'profile.saveProfile': {
    'en': 'Save profile',
    'sn': 'Chengetedza mamiriro',
    'nd': 'Londoloza iphrofayili',
  },
  'profile.saved': {
    'en': 'Profile saved on this device.',
    'sn': 'Mamiriro akachengetedzwa pane iyi device.',
    'nd': 'Iphrofayili ilondolozwe kule device.',
  },
  'profile.usizoPlus': {
    'en': 'UsizoAI Plus',
    'sn': 'UsizoAI Plus',
    'nd': 'I-UsizoAI Plus',
  },
  'profile.unlimitedChecksEnabled': {
    'en': 'Unlimited checks enabled.',
    'sn': 'Matarisiro asina muganhu akavhurwa.',
    'nd': 'Izibheko ezingenamkhawulo zivuliwe.',
  },
  'profile.unlockPlus': {
    'en': 'Unlock UsizoAI Plus',
    'sn': 'Vhura UsizoAI Plus',
    'nd': 'Vula i-UsizoAI Plus',
  },
  'profile.plusDescription': {
    'en': 'Unlimited checks, saved history, and more.',
    'sn': 'Matarisiro asina muganhu, ruzivo rwakachengetedzwa, nezvimwe.',
    'nd': 'Izibheko ezingenamkhawulo, ubufakazi obulondoloziwe, nezinye.',
  },
  'profile.payWithEcoCash': {
    'en': 'Pay with EcoCash',
    'sn': 'Bhadhara neEcoCash',
    'nd': 'Khokha nge-EcoCash',
  },
  'profile.hasToken': {
    'en': 'I have a token',
    'sn': 'Ndina token',
    'nd': 'Nginetokeni',
  },
  'profile.yourVendorShop': {
    'en': 'Your vendor shop',
    'sn': 'Shoko yako yemutengesi',
    'nd': 'Ishophi yakho yomthengisi',
  },
  'profile.sellOnUsizo': {
    'en': 'Sell on UsizoAI',
    'sn': 'Tengesa paUsizoAI',
    'nd': 'Thengisa ku-UsizoAI',
  },
  'profile.products': {
    'en': 'products',
    'sn': 'zvinhu',
    'nd': 'izinto',
  },
  'profile.signupDescription': {
    'en': 'Sign up and list your herbal products.',
    'sn': 'Pinda uye nyora zvinhu zvechiremedzi.',
    'nd': 'Bhalisa ubhalise izinto zakho zokwelapha.',
  },
  'profile.manageShop': {
    'en': 'Manage my shop',
    'sn': 'Simudza shoko yangu',
    'nd': 'Phatha ishophi yami',
  },
  'profile.becomeVendor': {
    'en': 'Become a vendor',
    'sn': 'Va mutengesi',
    'nd': 'Yiba umthengisi',
  },
  'profile.orderHistory': {
    'en': 'Order history',
    'sn': 'Ruzivo rwezvitengeso',
    'nd': 'Umlando wezinto',
  },
  // ── Cart ──────────────────────────────────────────────────────────
  'cart.title': {
    'en': 'Your cart',
    'sn': 'Kadhi yako',
    'nd': 'Ikhadi lakho',
  },
  'cart.empty': {
    'en': 'Your cart is empty',
    'sn': 'Kadhi yako iri %{empty}',
    'nd': 'Ikhadi lakho alikho lutho',
  },
  'cart.emptySubtitle': {
    'en': 'Browse the marketplace and add herbal products to your cart.',
    'sn': 'Tarisa mugadziriro uye wedzera zvinhu kuKadhi yako.',
    'nd': 'Bheka emakethe uye engeze izinto ekhadini lakho.',
  },
  'cart.total': {
    'en': 'Total',
    'sn': 'Zvose',
    'nd': 'Isamba',
  },
  'cart.placeOrder': {
    'en': 'Place order',
    'sn': 'pisa chikumbiro',
    'nd': 'Beka i-oda',
  },
  'cart.loading': {
    'en': 'Loading...',
    'sn': 'Kurira...',
    'nd': 'Iyalayisha...',
  },
  'cart.ordersNote': {
    'en':
        'Orders are saved on this device. Contact each vendor on WhatsApp to pay and arrange delivery.',
    'sn':
        'Zvitengeso zvakachengetedzwa pane iyi device. Batanai nevatengesi paWhatsApp kubhadhara nekutumira.',
    'nd':
        'Izinto zilondolozwe kule device. Xhumana nabathengisi nge-WhatsApp ukuze ukhokhe uthole.',
  },
  'cart.placeOrderTitle': {
    'en': 'Place order',
    'sn': 'Pisa chikumbiro',
    'nd': 'Beka i-oda',
  },
  'cart.placeOrderBody': {
    'en': 'Place order for',
    'sn': 'pisa chikumbiro che',
    'nd': 'Beka i-oda ye',
  },
  'cart.cancel': {
    'en': 'Cancel',
    'sn': 'Kanzura',
    'nd': 'Khansela',
  },
  'cart.orderPlaced': {
    'en': 'Order placed',
    'sn': 'Chikumbiro chakaiswa',
    'nd': 'I-oda ibekwe',
  },
  'cart.contactVendor': {
    'en': 'Contact vendor',
    'sn': 'Batana nemutengesi',
    'nd': 'Xhumana nomthengisi',
  },
  'cart.done': {
    'en': 'Done',
    'sn': 'Yaitwa',
    'nd': 'Kwenziwe',
  },
  // ── Emergency ─────────────────────────────────────────────────────
  'emergency.title': {
    'en': 'Urgent help',
    'sn': 'Rubatsiro rwakakosha',
    'nd': 'Usizo oluphuthumayo',
  },
  'emergency.pleaseGetHelp': {
    'en': 'Please get help now',
    'sn': 'Ndapota cherechedza rubatsiro izvozvi',
    'nd': 'Nceda uthole usizo manje',
  },
  'emergency.callServices': {
    'en': 'Call emergency services',
    'sn': 'Fona masevhisi echiremera',
    'nd': 'Biza izinsizakalo ephutha',
  },
  'emergency.findClinic': {
    'en': 'Find nearest clinic',
    'sn': 'Tsvaga chiparopa padivi',
    'nd': 'Thola ichinamisi esiseduze',
  },
  'emergency.returnToChecker': {
    'en': 'Return to checker',
    'sn': 'Dzoka kuChecker',
    'nd': 'Buyela ekuBhekeni',
  },
  'emergency.withSomeone': {
    'en':
        'If you are with someone who is unwell, stay with them and follow the dispatcher\'s instructions.',
    'sn':
        'Kana uri nemunhu ari kurwara, garo naye uye tevera mirairo yechiremera.',
    'nd':
        'Uma unesihlobo esigulayo, hlala nalo ulandele imiyalo yosizo.',
  },
  'emergency.openingDialer': {
    'en': 'Opening your emergency dialer…',
    'sn': 'Kuvhura dhaiala yechiremera…',
    'nd': 'Ivula i-dialer yaphutha…',
  },
  'emergency.dialNow': {
    'en': 'or your local emergency number now.',
    'sn': 'kana nhamburo yechiremera yegadziriro izvozvi.',
    'nd': 'noma inombolo yephutha yendawo manje.',
  },
  'emergency.findClinicMsg': {
    'en': 'Open Google Maps to find a clinic nearby.',
    'sn': 'Vhura Google Maps kuti utsvage chiparopa padivi.',
    'nd': 'Vula i-Google Maps ukuze uthole ichinamisi esiseduze.',
  },
  // ── Vendor Auth ───────────────────────────────────────────────────
  'vendorAuth.title': {
    'en': 'Vendor portal',
    'sn': 'Chengetedzwa chemutengesi',
    'nd': 'I-Portal yomthengisi',
  },
  'vendorAuth.signIn': {
    'en': 'Sign in',
    'sn': 'Pinda',
    'nd': 'Ngena',
  },
  'vendorAuth.signUp': {
    'en': 'Sign up',
    'sn': 'Pinda',
    'nd': 'Bhalisa',
  },
  'vendorAuth.signInTitle': {
    'en': 'Sign in to manage your shop',
    'sn': 'Pinda kusimudza shoko yako',
    'nd': 'Ngena ukuze uphathe ishophi yakho',
  },
  'vendorAuth.signInSubtitle': {
    'en': 'Use the phone number and PIN you registered with.',
    'sn': 'Shandisa nhamburo yefoni nePIN yawakanyorwa.',
    'nd': 'Sebenzisa inombolo yocingo ne-PIN oyibhalisile.',
  },
  'vendorAuth.phoneNumber': {
    'en': 'Phone number',
    'sn': 'Nhamburo yefoni',
    'nd': 'Inombolo yocingo',
  },
  'vendorAuth.pin': {
    'en': 'PIN',
    'sn': 'PIN',
    'nd': 'I-PIN',
  },
  'vendorAuth.signingIn': {
    'en': 'Signing in...',
    'sn': 'Kupinda...',
    'nd': 'Iyangena...',
  },
  'vendorAuth.signUpTitle': {
    'en': 'Join the UsizoAI marketplace',
    'sn': 'Pinda muUsizoAI mugadziriro',
    'nd': 'Ngena ku-UsizoAI makethe',
  },
  'vendorAuth.signUpSubtitle': {
    'en': 'Create your vendor profile and start listing herbal products.',
    'sn': 'Sika mamiriro ako emutengesi uye utange kunyora zvinhu zvechiremedzi.',
    'nd': 'Dala iphrofayili yakho yomthengisi uqale ukubhalisa izinto zokwelapha.',
  },
  'vendorAuth.businessName': {
    'en': 'Business name',
    'sn': 'Zita rebhizinesi',
    'nd': 'Igama lenkampani',
  },
  'vendorAuth.location': {
    'en': 'Location (city, suburb)',
    'sn': 'Nzvimbo (dhaungu, suburb)',
    'nd': 'Indawo (idolobha, isifunda)',
  },
  'vendorAuth.whatsappOptional': {
    'en': 'WhatsApp (optional)',
    'sn': 'WhatsApp (kunyangwe)',
    'nd': 'I-WhatsApp (ngokuzithandela)',
  },
  'vendorAuth.whatsappDefault': {
    'en': 'Defaults to your phone number if left blank',
    'sn': 'Inoshandisa nhamburo yefoni yako kana isina kuiswa',
    'nd': 'Isebenzisa inombolo yocingo yakho uma ingekiwe',
  },
  'vendorAuth.aboutBusiness': {
    'en': 'About your business',
    'sn': 'Nezvebhizinesi yako',
    'nd': 'Mayelana nenkampani yakho',
  },
  'vendorAuth.createPin': {
    'en': 'Create a PIN (4+ digits)',
    'sn': 'Sika PIN (4+ nhamba)',
    'nd': 'Dala i-PIN (amaphawindi 4+)',
  },
  'vendorAuth.confirmPin': {
    'en': 'Confirm PIN',
    'sn': 'Simbisa PIN',
    'nd': 'Qinisa i-PIN',
  },
  'vendorAuth.creatingAccount': {
    'en': 'Creating account...',
    'sn': 'Kusika account...',
    'nd': 'Idala i-akhawunti...',
  },
  'vendorAuth.createVendorAccount': {
    'en': 'Create vendor account',
    'sn': 'Sika account yemutengesi',
    'nd': 'Dala i-akhawunti yomthengisi',
  },
  'vendorAuth.shopSavedNote': {
    'en':
        'Your shop and products are saved on this device. Customers will see your listings in the marketplace immediately.',
    'sn':
        'Shoko yako nezvinhu zvakachengetedzwa pane iyi device. Vanhu vakoizozonzwa mumugadziriro zvino.',
    'nd':
        'Ishophi nezinto zakho zilondolozwe kule device. Abathengi bazokubona ku-makethe manje.',
  },
  // ── Activate ──────────────────────────────────────────────────────
  'activate.title': {
    'en': 'Activate Plus',
    'sn': 'Vhura Plus',
    'nd': 'Vula i-Plus',
  },
  'activate.enterToken': {
    'en': 'Enter your activation token',
    'sn': 'Pinda token yekuvhura',
    'nd': 'Faka i-tokeni yokuvula',
  },
  'activate.tokenInstructions': {
    'en':
        'After paying via EcoCash, you will receive a token. Enter it below to unlock UsizoAI Plus.',
    'sn':
        'Mushure mekubhadhara neEcoCash, uchawana token. Iisa pasi kuti uvhure UsizoAI Plus.',
    'nd':
        'Emva kokukhokha nge-EcoCash, uzothola itokeni. Ifake ngezansi ukuze uvule i-UsizoAI Plus.',
  },
  'activate.tokenHint': {
    'en': 'USIZO-XXXXXXXX',
    'sn': 'USIZO-XXXXXXXX',
    'nd': 'USIZO-XXXXXXXX',
  },
  'activate.activationToken': {
    'en': 'Activation token',
    'sn': 'Token yekuvhura',
    'nd': 'I-tokeni yokuvula',
  },
  'activate.activating': {
    'en': 'Activating...',
    'sn': 'Kuvhura...',
    'nd': 'Iyavula...',
  },
  'activate.activate': {
    'en': 'Activate',
    'sn': 'Vhura',
    'nd': 'Vula',
  },
  'activate.enterTokenError': {
    'en': 'Please enter your activation token.',
    'sn': 'Ndapota pinda token yekuvhura.',
    'nd': 'Nceda ufake i-tokeni yokuvula.',
  },
  'activate.activatedSuccess': {
    'en': 'UsizoAI Plus activated!',
    'sn': 'UsizoAI Plus yavhurwa!',
    'nd': 'I-UsizoAI Plus ivuliwe!',
  },
  'activate.invalidToken': {
    'en': 'Invalid token. Please check and try again.',
    'sn': 'Token haikosi. Ndapota tarisa uye ededza zvakare.',
    'nd': 'I-tokeni ayilungile. Nceda uhlole uphinde uzame.',
  },
  'activate.howToGetToken': {
    'en':
        'How to get a token:\n\n1. Pay \$1.50 via EcoCash to 0774605104\n2. You will receive your token shortly\n3. Enter it above to activate',
    'sn':
        'Nzira yekuwana token:\n\n1. Bhadhara \$1.50 neEcoCash ku0774605104\n2. Uchawana token yako padivi\n3. Iisa pamusoro kuti uvhure',
    'nd':
        'Indlela yokuthola itokeni:\n\n1. Khokha u-\$1.50 nge-EcoCash ku-0774605104\n2. Uzothola itokeni yakho maduze\n3. Ifake phezulu ukuze uvule',
  },
  // ── Payment Details ───────────────────────────────────────────────
  'payment.title': {
    'en': 'Payment instructions',
    'sn': 'Mirairo yekubhadhara',
    'nd': 'Imiyalo yokukhokha',
  },
  // ── Language selector ─────────────────────────────────────────────
  'lang.english': {
    'en': 'English',
    'sn': 'Chiunggaru',
    'nd': 'isiNgisi',
  },
  'lang.shona': {
    'en': 'Shona',
    'sn': 'ChiShona',
    'nd': 'isiShona',
  },
  'lang.ndebele': {
    'en': 'Ndebele',
    'sn': 'NaNdebele',
    'nd': 'isiNdebele',
  },
};

/// Simple helper to look up a string by key and language code.
/// Falls back to English if the key is missing for the requested language.
String s(String key, {String lang = 'en'}) {
  final entry = appStrings[key];
  if (entry == null) return key;
  return entry[lang] ?? entry['en'] ?? key;
}
