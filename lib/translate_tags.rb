PART_OF_SPEECH = {"A-"=>"adjective","Df"=>"adverb","S-"=>"article","Ma"=>"cardinal numeral","Nb"=>"common noun","C-"=>"conjunction","Pd"=>"demonstrative pronoun","F-"=>"foreign word","Px"=>"indefinite pronoun","N-"=>"infinitive marker","I-"=>"interjection","Du"=>"interrogative adverb","Pi"=>"interrogative pronoun","Mo"=>"ordinal numeral","Pp"=>"personal pronoun","Pk"=>"personal reflexive pronoun","Ps"=>"possessive pronoun","Pt"=>"possessive reflexive pronoun","R-"=>"preposition","Ne"=>"proper noun","Py"=>"quantifier","Pc"=>"reciprocal pronoun","Dq"=>"relative adverb","Pr"=>"relative pronoun","G-"=>"subjunction","V-"=>"verb","X-"=>"unassigned"}

def translate_part_of_speech(tag)
  PART_OF_SPEECH[tag]
end

RELATION = {"adnom"=>"adnominal","adv"=>"adverbial","ag"=>"agens","apos"=>"apposition","arg"=>"argument (object or oblique)","atr"=>"attribute","aux"=>"auxiliary","comp"=>"complement","expl"=>"expletive","narg"=>"adnominal argument","nonsub"=>"non-subject (object, oblique or adverbial)","obj"=>"object","obl"=>"oblique","parpred"=>"parenthetical predication","part"=>"partitive","per"=>"peripheral (oblique or adverbial)","pid"=>"Predicate identity","pred"=>"predicate","rel"=>"apposition or attribute","sub"=>"subject","voc"=>"vocative","xadv"=>"open adverbial complement","xobj"=>"open objective complement","xsub"=>"external subject"}

def translate_relation(tag)
  RELATION[tag]
end

PERSON     = {"1"=>"first person","2"=>"second person","3"=>"third person","x"=>"uncertain person"}
NUMBER     = {"s"=>"singular","d"=>"dual","p"=>"plural","x"=>"uncertain number"}
TENSE      = {"p"=>"present","i"=>"imperfect","r"=>"perfect","s"=>"resultative","a"=>"aorist","u"=>"past","l"=>"pluperfect","f"=>"future","t"=>"future perfect","x"=>"uncertain tense"}
MOOD       = {"i"=>"indicative","s"=>"subjunctive","m"=>"imperative","o"=>"optative","n"=>"infinitive","p"=>"participle","d"=>"gerund","g"=>"gerundive","u"=>"supine","x"=>"uncertain mood","y"=>"finiteness unspecified","e"=>"indicative or subjunctive","f"=>"indicative or imperative","h"=>"subjunctive or imperative","t"=>"finite"}
VOICE      = {"a"=>"active","m"=>"middle","p"=>"passive","e"=>"middle or passive","x"=>"unspecified"}
GENDER     = {"m"=>"masculine","f"=>"feminine","n"=>"neuter","p"=>"masculine or feminine","o"=>"masculine or neuter","r"=>"feminine or neuter","q"=>"masculine, feminine or neuter","x"=>"uncertain gender"}
CASE       = {"n"=>"nominative","a"=>"accusative","o"=>"oblique","g"=>"genitive","c"=>"genitive or dative","e"=>"accusative or dative","d"=>"dative","b"=>"ablative","i"=>"instrumental","l"=>"locative","v"=>"vocative","x"=>"uncertain case","z"=>"no case"}
DEGREE     = {"p"=>"positive","c"=>"comparative","s"=>"superlative","x"=>"uncertain degree","z"=>"no degree"}
STRENGTH   = {"w"=>"weak","s"=>"strong","t"=>"weak or strong"}
INFLECTION = {"n"=>"non-inflecting","i"=>""}

def translate_morphology(tag)
  if tag
    puts tag
    person, number, tense, mood, voice, gender, kase, degree, strength, inflection = tag.split(//)
    [PERSON[person], NUMBER[number], TENSE[tense], MOOD[mood], VOICE[voice], GENDER[gender], CASE[kase], DEGREE[degree], STRENGTH[strength], INFLECTION[inflection]].compact.reject(&:empty?).join(',')
  else
    ''
  end
end
