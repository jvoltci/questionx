/// Maps JEE Physics/Chemistry topics onto the NEET topics that cover the same
/// syllabus, so a NEET student practising a topic can pull in JEE questions on
/// the same material.
///
/// **Keyed by JEE topic on purpose.** JEE has 32 clean topics per subject; NEET
/// has 61 Physics and 109 Chemistry, and they are messy — four spellings of
/// "Dual Nature of ...", a typo (`Kinsctic Theory of Gases`), and 72 Chemistry
/// topics holding fewer than five questions each. Mapping from the NEET side
/// would be 170 entries to curate; from here it is 64, and the inversion is
/// computed once at runtime by [neetTopicToJeeTopics].
///
/// NEET and JEE Main share roughly 85–90% of their Physics and Chemistry
/// syllabi, so every JEE topic here has a NEET counterpart. Two are marginal and
/// noted inline rather than dropped, because their questions are still useful
/// practice on material NEET does examine.
///
/// Names on both sides must match the banks exactly — `cross_exam_topics_test`
/// fails the build if a JEE topic is missing from this map or a NEET name here
/// does not exist in the bank.
library;

/// JEE topic -> NEET topics covering the same syllabus.
const Map<String, List<String>> kJeeToNeetPhysics = {
  'Heat And Thermodynamics': [
    'Thermodynamics',
    'Kinetic Theory',
    'Kinetic Theory of Gases',
    'Kinsctic Theory of Gases', // typo present in the NEET bank
    'Thermal Properties',
    'Thermal Properties of Matter',
  ],
  'Current Electricity': ['Current Electricity', 'Chemical Effects of Current'],
  'Properties Of Matter': [
    'Mechanical Properties of Fluids',
    'Mechanical Properties of Solids',
    'Properties of Fluids',
    'Properties of Solids',
    'Properties of Solids and Liquids',
    'Fluid Mechanics',
    'Fluids',
  ],
  'Geometrical Optics': ['Ray Optics', 'Ray Optics and Optical Instruments'],
  'Atoms And Nuclei': ['Atoms', 'Nuclei', 'Radioactivity'],
  'Electrostatics': [
    'Electrostatics',
    'Electric Charges and Fields',
    'Electrostatic Potential and Capacitance',
  ],
  'Rotational Motion': [
    'Rotational Motion',
    'System of Particles',
    'System of Particles and Rotational Motion',
  ],
  'Units And Measurements': ['Units and Measurements', 'Units and Dimensions'],
  'Magnetics': ['Moving Charges and Magnetism', 'Magnetic Effects of Current'],
  'Dual Nature Of Radiation': [
    'Dual Nature of Matter',
    'Dual Nature of Matter and Radiation',
    'Dual Nature of Radiation',
    'Dual Nature of Radiation and Matter',
  ],
  'Gravitation': ['Gravitation'],
  'Wave Optics': ['Wave Optics'],
  'Alternating Current': [
    'Alternating Current',
    'AC Circuits',
    'EMI & AC',
    'EMI and AC',
  ],
  'Electronic Devices': ['Semiconductor Electronics', 'Semiconductors'],
  'Electromagnetic Waves': ['Electromagnetic Waves', 'EM Waves'],
  'Capacitor': ['Capacitance', 'Electrostatic Potential and Capacitance'],
  'Simple Harmonic Motion': ['Oscillations'],
  'Waves': ['Waves'],
  'Electromagnetic Induction': ['Electromagnetic Induction', 'EMI'],
  'Work Power And Energy': ['Work, Energy and Power', 'Work, Energy, Power'],
  'Laws Of Motion': ['Laws of Motion'],
  'Center Of Mass': [
    'System of Particles',
    'System of Particles and Rotational Motion',
  ],
  'Motion In A Straight Line': ['Motion in a Straight Line', 'Kinematics'],
  'Communication Systems': ['Communication Systems'],
  'Motion In A Plane': ['Motion in a Plane', 'Kinematics'],
  'Circular Motion': ['Circular Motion'],
  'Magnetic Properties Of Matter': ['Magnetism', 'Magnetism and Matter'],
  'Vector Algebra': ['Vectors'],
  'Magnetism': ['Magnetism', 'Magnetism and Matter'],
  'Motion': ['Kinematics', 'Motion in a Straight Line'],
  'Impulse And Momentum': ['Laws of Motion'],
  // Marginal: NEET does not test experimental skills as its own unit, but the
  // questions are error-analysis, which NEET examines under Units & Measurements.
  'Practical Physics': ['Units and Measurements'],
};

/// JEE topic -> NEET topics covering the same syllabus.
const Map<String, List<String>> kJeeToNeetChemistry = {
  'Coordination Compounds': [
    'Coordination Compounds',
    'Coordination Chemistry',
    'Inorganic Chemistry - Coordination Compounds',
  ],
  'P Block Elements': [
    'p-Block Elements',
    'P-Block Elements',
    'Inorganic Chemistry - p-Block',
    'Inorganic Chemistry - p-Block (Noble Gases)',
  ],
  'Some Basic Concepts Of Chemistry': [
    'Some Basic Concepts of Chemistry',
    'Some Basic Concepts',
    'Mole Concept',
    'Stoichiometry',
    'Physical Chemistry - Stoichiometry',
  ],
  'Thermodynamics': [
    'Thermodynamics',
    'Physical Chemistry - Thermodynamics',
    'Thermodynamics / Kinetics',
  ],
  'D And F Block Elements': [
    'd and f Block Elements',
    'd- and f-Block Elements',
    'd-Block Elements',
    'f-Block Elements',
    'Inorganic Chemistry - d-Block',
    'Solid State / d-block',
  ],
  'Chemical Bonding And Molecular Structure': [
    'Chemical Bonding',
    'Chemical Bonding and Molecular Structure',
    'Chemical Bonding / GOC',
    'Inorganic Chemistry - Chemical Bonding',
  ],
  'Basics Of Organic Chemistry': [
    'General Organic Chemistry',
    'Organic Chemistry',
    'Organic Chemistry - Basic Principles',
    'Organic Chemistry - Basics',
    'Organic Chemistry - Some Basic Principles',
    'Organic Chemistry - Some Basic Principles and Techniques',
    'Organic Chemistry: Some Basic Principles',
    'Organic Chemistry - Isomerism',
    'Organic Chemistry - Name Reactions',
    'Organic Chemistry - Nomenclature',
    'Stereochemistry',
    'IUPAC Naming',
    'IUPAC Nomenclature',
    'Nomenclature',
  ],
  'Electrochemistry': [
    'Electrochemistry',
    'Physical Chemistry - Electrochemistry',
  ],
  'Structure Of Atom': [
    'Structure of Atom',
    'Atomic Structure',
    'Physical Chemistry - Structure of Atom',
  ],
  'Chemical Kinetics And Nuclear Chemistry': [
    'Chemical Kinetics',
    'Physical Chemistry - Chemical Kinetics',
    'Nuclear Chemistry',
  ],
  'Solutions': ['Solutions', 'Solutions / Surface Chemistry'],
  'Periodic Table And Periodicity': [
    'Periodic Classification',
    'Periodic Classification of Elements',
    'Periodic Properties',
    'Periodic Table',
    'Periodicity',
    'Classification of Elements',
    'Classification of Elements and Periodicity',
    'Classification of Elements and Periodicity in Properties',
    'Inorganic Chemistry - Periodic Properties',
  ],
  'Biomolecules': [
    'Biomolecules',
    'Biomolecules (Chemistry)',
    'Organic Chemistry - Biomolecules',
  ],
  'Ionic Equilibrium': [
    'Ionic Equilibrium',
    'Equilibrium',
    'Physical Chemistry - Equilibrium',
  ],
  'Aldehydes Ketones And Carboxylic Acids': [
    'Aldehydes, Ketones and Carboxylic Acids',
    'Carboxylic Acids',
    'Organic Chemistry - Aldehydes and Ketones',
  ],
  'Isolation Of Elements': [
    'General Principles and Processes of Isolation of Elements',
    'General Principles of Isolation of Elements',
    'General Principles of Metallurgy',
    'Metallurgy',
    'Inorganic Chemistry - Metallurgy',
  ],
  'Compounds Containing Nitrogen': [
    'Amines',
    'Organic Chemistry - Amines',
    'Organic Chemistry - Amines/Haloarenes',
    'Organic Compounds Containing Nitrogen',
  ],
  'Surface Chemistry': [
    'Surface Chemistry',
    'Physical Chemistry - Surface Chemistry',
  ],
  'S Block Elements': ['s-Block Elements', 'Inorganic Chemistry - s-Block'],
  'Chemical Equilibrium': ['Chemical Equilibrium', 'Equilibrium'],
  'Environmental Chemistry': ['Environmental Chemistry'],
  'Hydrogen': ['Hydrogen', 'Inorganic Chemistry - Hydrogen'],
  'Redox Reactions': [
    'Redox Reactions',
    'Physical Chemistry - Redox Reactions',
  ],
  'Alcohols Phenols And Ethers': [
    'Alcohols, Phenols and Ethers',
    'Organic Chemistry - Alcohols',
    'Organic Chemistry - Alcohols, Phenols and Ethers',
  ],
  'Hydrocarbons': [
    'Hydrocarbons',
    'Hydrocarbons / Organic',
    'Organic Chemistry - Hydrocarbons',
  ],
  'Haloalkanes And Haloarenes': [
    'Haloalkanes and Haloarenes',
    'Haloalkanes',
    'Organic Chemistry - Haloalkanes',
  ],
  'Chemistry In Everyday Life': ['Chemistry in Everyday Life'],
  'Solid State': ['Solid State', 'Physical Chemistry - Solid State'],
  'Gaseous State': ['States of Matter', 'Physical Chemistry - States of Matter'],
  'Polymers': ['Polymers', 'Organic Chemistry - Polymers'],
  'Practical Organic Chemistry': [
    'Practical Chemistry',
    'Purification',
    'Organic Chemistry - Purification',
    'Organic Chemistry - Analysis',
    'Qualitative Analysis',
    'Organic Chemistry - Qualitative Analysis',
  ],
  // Marginal: NEET has no salt-analysis unit, but these test ionic reactions
  // and precipitate colours, which it examines under p-block and d-block.
  'Salt Analysis': ['Qualitative Analysis', 'Practical Chemistry'],
};

/// Every mapping, both subjects.
const Map<String, List<String>> kJeeToNeetTopics = {
  ...kJeeToNeetPhysics,
  ...kJeeToNeetChemistry,
};

Map<String, List<String>> _invert(Map<String, List<String>> forward) {
  final out = <String, List<String>>{};
  forward.forEach((jee, neetTopics) {
    for (final neet in neetTopics) {
      (out[neet] ??= <String>[]).add(jee);
    }
  });
  return out;
}

Map<String, List<String>>? _physCache;
Map<String, List<String>>? _chemCache;

/// NEET topic -> JEE topics covering the same syllabus, per subject.
///
/// Built by inverting the curated maps on first use, so the reviewable file
/// stays the small direction. Kept per-subject because `Biomolecules` is a topic
/// name in NEET **Biology** as well as NEET Chemistry — a single combined
/// inversion would let a Biology selection reach for JEE Chemistry questions.
Map<String, List<String>> get neetTopicToJeePhysics =>
    _physCache ??= _invert(kJeeToNeetPhysics);
Map<String, List<String>> get neetTopicToJeeChemistry =>
    _chemCache ??= _invert(kJeeToNeetChemistry);

/// The JEE topics that together cover [neetTopics] within [subject].
///
/// Any subject other than Physics or Chemistry returns empty — Biology has no
/// JEE counterpart — so callers need no special-casing.
List<String> jeeTopicsFor(Iterable<String> neetTopics, String subject) {
  final s = subject.toLowerCase();
  final Map<String, List<String>> lookup;
  if (s.startsWith('phys')) {
    lookup = neetTopicToJeePhysics;
  } else if (s.startsWith('chem')) {
    lookup = neetTopicToJeeChemistry;
  } else {
    return const [];
  }
  final out = <String>{};
  for (final t in neetTopics) {
    final mapped = lookup[t];
    if (mapped != null) out.addAll(mapped);
  }
  return out.toList()..sort();
}

/// Whether cross-exam practice is offered for [subject] at all.
bool supportsCrossExam(String subject) {
  final s = subject.toLowerCase();
  return s.startsWith('phys') || s.startsWith('chem');
}
