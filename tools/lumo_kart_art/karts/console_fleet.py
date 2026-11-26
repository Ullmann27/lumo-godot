"""Original coachwork for ten production karts, using the existing fitted chassis."""

# Mechanical platform, paint, trim, accent, luminous accent.
DESIGNS = {
    "kupferpfeil": ("comet", "BD5A41", "FFF0C8", "6B281E", "FFC775"),
    "duenenspur": ("comet", "DEAE5F", "913A24", "5C7175", "FFE7A3"),
    "schneewacht": ("comet", "367795", "E9F4F0", "D34F35", "A2F7FF"),
    "kristallfalter": ("glider", "8B62BA", "CBE8FF", "403878", "96EDFA"),
    "hafenflitzer": ("glider", "36958A", "E6B67C", "F4E7BB", "D4FDEC"),
    "glutstrom": ("turbo", "BD3930", "FFA051", "262730", "FFD475"),
    "wolkenkurier": ("glider", "EACCCE", "496FAD", "FF9D6A", "FFF0BF"),
    "mooslaeufer": ("comet", "58804C", "F7C464", "605137", "FAEB9C"),
    "mondsprint": ("turbo", "354873", "BACDD7", "CA6D8F", "BDD9FF"),
    "werkmeister": ("comet", "D98234", "3A6164", "F6C67D", "FFF0AA"),
}


def kupferpfeil(c):
    c.sides(.20, .14, "a")
    c.loft("Torpedo cowl", [(-1.33,.045,.038,.37),(-1.25,.15,.12,.42),
           (-1.06,.235,.16,.476),(-.77,.265,.19,.489),(-.37,.34,.18,.445)])
    c.bulb("Copper radiator surround", (0,.476,-1.19), (.148,.168,.092), "m")
    c.bulb("Black radiator inset", (0,.48,-1.25), (.128,.138,.042), "c")
    for x in (-.09,-.06,-.03,0,.03,.06,.09):
        c.box("Radiator reed", (x,.478,-1.288+abs(x)*.16), (.007,.243-abs(x),.011), "m", .003)
    for side in (-1,1):
        c.arch(side,-.80,.70,.26,.665,"p")
        c.arch(side,.77,.63,.30,.67,"p")
        c.lamp(side*.29,.554,-1.034,.079)
        c.tube("Running-board pipe", [(side*.42,.36,-.59),(side*.52,.36,-.36),
               (side*.57,.36,.10),(side*.53,.37,.49)], .027, "m")
    c.stripe([(0,.617,-1.24),(0,.641,-1.05),(0,.685,-.77),(0,.648,-.37)], .055, "t")


def duenenspur(c):
    c.sides(.16,.12,"a",.41)
    c.loft("High cutaway bonnet", [(-1.20,.14,.055,.27),(-1.11,.25,.074,.33),
           (-.86,.27,.118,.445),(-.55,.32,.12,.48),(-.35,.267,.12,.467)], power=.44)
    c.grille(-1.15,.33,.10,.365)
    for side in (-1,1):
        c.arch(side,.77,.67,.27,.70,"p",True)
        c.tube("Side chassis rail", [(side*.35,.34,-1.14),(side*.47,.35,-.86),
               (side*.51,.41,-.41),(side*.55,.41,.35),(side*.49,.53,.73)], .044,"t")
        c.tube("Rear roll hoop foot", [(side*.36,.58,.49),(side*.40,1.04,.55),
               (side*.32,1.27,.61),(side*.19,1.35,.62)], .036,"a")
        c.tube("Roll hoop diagonal", [(side*.31,1.27,.61),(side*.38,.60,.99)], .025,"m")
        c.lamp(side*.272,.49,-1.098,.068)
    c.tube("Cage crossbar", [(-.19,1.35,.62),(0,1.36,.62),(.19,1.35,.62)], .036,"a")
    c.box("Sand ladders carrier", (0,.63,1.03), (.62,.07,.17), "t")
    for x in (-.22,-.11,0,.11,.22):
        c.box("Carrier slot", (x,.675,1.035), (.058,.023,.14), "m", .009)


def schneewacht(c):
    c.sides(.21,.16,"p",.48)
    c.loft("White utility bonnet", [(-1.13,.27,.104,.48),(-1.04,.34,.13,.49),
           (-.74,.37,.15,.53),(-.36,.365,.13,.49)],"t",power=.34)
    c.grille(-1.155,.37,.16,.49)
    c.blade("Curved impact bumper", [(x,.25+abs(x)*.09,-1.25+abs(x)*.20,.19,.16)
            for x in (-.69,-.52,-.22,0,.22,.52,.69)],"p")
    for side in (-1,1):
        c.arch(side,-.80,.74,.32,.695,"p",True)
        c.arch(side,.77,.69,.28,.68,"t",True)
        c.box("Ice searchlight", (side*.28,.58,-1.10), (.15,.097,.076),"c")
        c.box("Pale searchlight lens", (side*.28,.58,-1.145), (.129,.062,.021),"l",.009)
        c.box("Winter bumper insert", (side*.31,.31,-1.288), (.20,.039,.025),"a",.008)
        c.panel("Rear lamp pylon", [(side*.33,.55,.74),(side*.42,.76,.82),
                (side*.43,.79,1.03),(side*.33,.53,1.06)],.067,"p")
        c.box("Service light", (side*.416,.793,.97), (.081,.052,.11),"a",.015)


def kristallfalter(c):
    c.sides(.18,.13,"a",.32)
    c.loft("Faceted ridge", [(-1.38,.026,.026,.32),(-1.18,.17,.09,.42),
           (-.93,.21,.163,.48),(-.69,.27,.167,.49),(-.36,.32,.13,.45)],power=.27)
    for side in (-1,1):
        c.blade("Crystal shoulder", [(side*.18,.50,-.73,.54,.14),
                (side*.44,.57,-.58,.84,.16),(side*.73,.60,-.44,.53,.12),
                (side*.91,.67,-.19,.22,.043)],"t")
        c.blade("Lower crystal facet", [(side*.24,.37,-.65,.39,.10),
                (side*.52,.43,-.40,.70,.07),(side*.75,.46,-.37,.46,.043)],"p")
        c.tailfin(side,.38,.58,1.02,.56,1.01,"t")
        c.tube("Crystal lamp vein", [(side*.05,.388,-1.30),(side*.16,.497,-1.12),
               (side*.24,.564,-.91)],.023,"l")
    c.spoiler(.69,.89,1.07,.17,"p")


def hafenflitzer(c):
    c.sides(.19,.14,"t")
    c.loft("Foredeck", [(-1.37,.018,.039,.43),(-1.24,.15,.071,.42),
           (-1.02,.24,.10,.47),(-.68,.33,.14,.49),(-.36,.37,.16,.45)],power=.75)
    c.loft("Mahogany-look foredeck insert", [(-1.28,.02,.02,.504),(-1.11,.16,.022,.55),
           (-.78,.23,.025,.615),(-.46,.24,.026,.61)],"t")
    for side in (-1,1):
        c.loft("Pontoon sheer", [(-.95,.028,.027,.42),(-.69,.093,.096,.48),
               (-.26,.132,.135,.43),(.27,.13,.135,.43),(.58,.11,.11,.49),
               (.95,.04,.03,.51)],"p",side*.52)
        c.tube("Rub rail", [(side*.548,.46,-.91),(side*.624,.48,-.54),
               (side*.65,.44,.03),(side*.64,.45,.52),(side*.58,.54,.84)], .020,"a")
        c.lamp(side*.208,.515,-1.08,.06)
        c.box("Deck cleat", (side*.32,.66,.80),(.16,.047,.047),"m",.017)
    c.spoiler(.58,.86,1.00,.26,"t")


def glutstrom(c):
    c.sides(.23,.16,"p",.46)
    c.loft("Radiator shoulders", [(-1.28,.19,.075,.36),(-1.14,.31,.11,.43),
           (-.96,.37,.14,.48),(-.70,.37,.13,.50),(-.37,.30,.12,.47)],power=.46)
    c.loft("Heat exchanger bulge", [(-1.14,.126,.055,.56),(-1.03,.17,.098,.59),
           (-.77,.163,.078,.60),(-.40,.116,.024,.57)],"c",power=.32)
    c.grille(-1.21,.34,.116,.46)
    for side in (-1,1):
        c.blade("Split radiator lip", [(side*.08,.228,-1.24,.29,.075),
                (side*.42,.28,-1.12,.39,.086),(side*.70,.39,-.93,.32,.063)],"a")
        c.box("Blade lamp", (side*.298,.545,-1.064),(.17,.042,.050),"l",.012)
        for z in (-.22,-.08,.06,.20):
            c.box("Heat-sink gill", (side*.677,.46,z),(.034,.124,.049),"t",.012)
        c.tailfin(side,.45,.59,.83,.53,1.04,"a")
    c.spoiler(.66,.78,1.08,.18,"p")


def wolkenkurier(c):
    c.sides(.18,.14,"p")
    c.loft("Pearl centre cowl", [(-1.17,.033,.06,.36),(-1.05,.15,.09,.42),
           (-.72,.235,.144,.46),(-.36,.33,.15,.46)])
    for side in (-1,1):
        c.loft("Wingtip nacelle", [(-1.19,.027,.03,.35),(-1.08,.091,.082,.40),
               (-.85,.105,.106,.455),(-.47,.127,.098,.45),(-.28,.026,.035,.44)],
               "t",side*.391)
        c.bulb("Projector set", (side*.391,.43,-1.104),(.074,.064,.038),"l")
        c.blade("Carry wing", [(side*.25,.48,-.53,.51,.091),
                (side*.55,.51,-.37,.76,.109),(side*.86,.57,-.31,.26,.059)],"p")
        c.tailfin(side,.44,.57,1.13,.28,.99,"a")
    c.spoiler(.51,.89,.99,.21,"t")


def mooslaeufer(c):
    c.sides(.21,.16,"p",.82)
    c.loft("Rounded trail bonnet", [(-1.24,.10,.055,.35),(-1.12,.26,.122,.42),
           (-.9,.37,.17,.49),(-.65,.38,.14,.49),(-.36,.345,.13,.45)])
    c.grille(-1.18,.36,.11,.395)
    for side in (-1,1):
        c.arch(side,-.77,.74,.34,.69,"p")
        c.arch(side,.79,.76,.32,.685,"p")
        c.lamp(side*.319,.55,-1.009,.089)
        c.tube("Wraparound cage", [(side*.27,.33,-1.22),(side*.50,.37,-1.05),
               (side*.61,.37,-.64),(side*.64,.41,-.27)], .037,"t")
        c.tube("Rear grab rail", [(side*.34,.55,.54),(side*.45,.71,.67),
               (side*.46,.74,.82),(side*.42,.64,.99)], .028,"t")
        c.tube("Wheel-arch edging", [(side*.79,.49,-1.016),(side*.81,.65,-.93),
               (side*.83,.728,-.76),(side*.817,.684,-.55)],.019,"c")
    c.stripe([(0,.529,-1.17),(0,.607,-1.08),(0,.675,-.91),(0,.655,-.65)],.13,"a")


def mondsprint(c):
    c.sides(.18,.14,"a",.33)
    c.loft("Raised central spine", [(-1.23,.025,.026,.37),(-1.07,.10,.085,.44),
           (-.79,.14,.145,.52),(-.52,.17,.156,.49),(-.33,.23,.109,.45)],"t",power=.42)
    for side in (-1,1):
        c.loft("Twin nose beam", [(-1.41,.04,.043,.37),(-1.29,.093,.05,.405),
               (-1.08,.11,.095,.452),(-.72,.127,.12,.45),(-.36,.13,.113,.43)],
               "p",side*.282,.38)
        c.tube("Twin beam running light", [(side*.282,.411,-1.408),
               (side*.28,.467,-1.219),(side*.3,.545,-1.042)],.021,"l")
        c.blade("Arced rear shoulder", [(side*.29,.46,.28,.57,.131),
                (side*.56,.56,.41,.66,.12),(side*.77,.62,.74,.49,.075)],"p")
        c.tailfin(side,.52,.63,1.055,.36,1.07,"t")
    c.spoiler(.72,1.01,1.06,.17,"p")


def werkmeister(c):
    c.sides(.22,.16,"p",.34)
    c.loft("Chamfered carrier nose", [(-1.17,.17,.084,.396),(-1.08,.34,.133,.43),
           (-.83,.39,.155,.50),(-.34,.369,.153,.48)],power=.34)
    c.grille(-1.166,.38,.123,.471)
    c.box("Utility cross bumper", (0,.27,-1.185), (1.29,.115,.145),"t",.031)
    for side in (-1,1):
        c.arch(side,-.78,.78,.34,.70,"p",True)
        c.arch(side,.77,.74,.34,.725,"t",True)
        c.box("Recessed headlamp", (side*.293,.522,-1.095),(.158,.088,.083),"c",.02)
        c.box("Work lamp lens", (side*.293,.522,-1.144),(.127,.060,.025),"l",.008)
        c.box("Tool locker", (side*.56,.54,.603),(.20,.21,.32),"p",.033)
        c.box("Pressed locker handle", (side*.668,.551,.59),(.033,.033,.116),"m",.009)
        for z in (-.11,.09,.29):
            c.box("Checker-plate step", (side*.632,.32,z),(.19,.046,.13),"t",.013)
    c.box("Tail platform", (0,.70,.989),(.60,.076,.16),"t",.019)


BUILD = {builder.__name__: builder for builder in (
    kupferpfeil, duenenspur, schneewacht, kristallfalter, hafenflitzer,
    glutstrom, wolkenkurier, mooslaeufer, mondsprint, werkmeister,
)}
