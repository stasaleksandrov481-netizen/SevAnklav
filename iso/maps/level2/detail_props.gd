extends RefCounted
# All details append to the existing shared mesh batches. No per-frame scripts.
const WARM=Color("#c5c0a8")
const RUBBER=Color("#293432")
const COPPER=Color("#8f6650")
const BLUE=Color("#607b89")
static func mug(f,p,at:Vector3)->void:
 f.tube(p,.055,.105,at+Vector3(0,.05,0),WARM)
 f.ring(p,.041,.056,at+Vector3(0,.105,0),WARM)
 f.tube(p,.039,.003,at+Vector3(0,.106,0),Color("#473e32"))
 f.ring(p,.027,.04,at+Vector3(.07,.06,0),WARM,Vector3(PI/2,0,0))
static func decorate(f,p,kind:String,index:int)->void:
 var n=index%3
 match kind:
  "desk","pc","bench","lab":
   if kind!="lab" and not str(p.get_meta("furniture_id","")).begins_with("isolation"):mug(f,p,Vector3(.58,.835,-.13))
   f.box(p,Vector3(.22,.012,.31),Vector3(-.51,.84,.12),BLUE)
   f.box(p,Vector3(.19,.006,.26),Vector3(-.51,.85,.12),WARM)
   f.box(p,Vector3(.08,.014,.025),Vector3(-.51,.86,-.02),f.STEEL)
   f.tube(p,.006,.15,Vector3(-.31,.85,.08),COPPER,Vector3(0,0,PI/2))
   if kind=="pc":
    for x in range(9):
     for z in range(3):f.box(p,Vector3(.035,.008,.027),Vector3(-.18+x*.045,.871,.065+z*.045),f.PALE)
    for i in range(6):f.tube(p,.008,.065,Vector3(.34,.84,-.18+i*.045),RUBBER,Vector3(PI/2,0,.2))
    f.soft(p,Vector3(.07,.028,.105),Vector3(.4,.85,.15),RUBBER)
   if kind=="lab":
    f.ring(p,.07,.085,Vector3(.52,.852,.1),f.PALE)
    f.tube(p,.065,.007,Vector3(.52,.853,.1),Color("#718f7b"))
    for x in range(3):
     f.tube(p,.024,.12,Vector3(.19+x*.09,.95,.18),BLUE)
     f.tube(p,.028,.025,Vector3(.19+x*.09,1.02,.18),WARM)
   if n==1:f.soft(p,Vector3(.16,.003,.1),Vector3(.45,.839,.06),Color("#54483a"))
  "bed","capsule":
   f.soft(p,Vector3(.58,.09,.73),Vector3(.53,.9,0),BLUE)
   for x in [-.9,.9]:
    for z in [-.34,.34]:
     f.tube(p,.065,.055,Vector3(x,.065,z),RUBBER,Vector3(0,0,PI/2))
   if kind=="bed":
    f.tube(p,.014,.8,Vector3(0,1.02,-.39),f.STEEL,Vector3(0,0,PI/2))
    f.tube(p,.015,1.1,Vector3(.78,1.22,.3),f.STEEL)
    f.soft(p,Vector3(.16,.28,.07),Vector3(.66,1.6,.3),Color("#91b3b1"))
    f.tube(p,.005,.7,Vector3(.66,1.12,.3),WARM)
   else:
    for side in [-1,1]:
     for j in range(6):
      var a=j*TAU/6
      f.tube(p,.019,.035,Vector3(side*1.06,1+cos(a)*.52,sin(a)*.52),f.PALE,Vector3(0,0,PI/2))
    f.box(p,Vector3(.25,.035,.18),Vector3(.76,.92,.29),f.DARK)
    f.box(p,Vector3(.19,.015,.12),Vector3(.76,.945,.29),BLUE)
  "locker","server","panel":
   f.box(p,Vector3(.22,.08,.012),Vector3(-.2,1.72,.33),WARM)
   for i in range(3):f.box(p,Vector3(.12,.006,.006),Vector3(-.2,1.7+i*.018,.34),f.DARK)
   if kind=="server":
    for i in range(8):f.box(p,Vector3(.47,.012,.008),Vector3(.03,.3+i*.19,.253),f.STEEL)
    for i in range(6):f.tube(p,.009,.2,Vector3(-.27+i*.018,.28,-.26),COPPER if i%2==0 else BLUE)
   if kind=="panel":
    f.box(p,Vector3(.25,.18,.014),Vector3(0,1.3,.33),WARM)
    for x in [-.055,.055]:f.tube(p,.025,.018,Vector3(x,1.3,.35),f.RED if x<0 else f.DARK,Vector3(PI/2,0,0))
  "shelf":
   for h in [.3,.84,1.37,1.9]:
    for x in [-.27,0,.27]:f.box(p,Vector3(.11,.055,.006),Vector3(x,h,.169),WARM)
  "chair":
   if index%2==0:
    f.soft(p,Vector3(.36,.13,.18),Vector3(0,.94,-.22),BLUE)
    f.soft(p,Vector3(.12,.36,.08),Vector3(-.19,.78,-.23),BLUE)
    f.box(p,Vector3(.06,.04,.01),Vector3(.08,.91,-.10),WARM)
  "pump","generator","tank":
   var face=Node3D.new();p.add_child(face);face.position=Vector3(.67,1.0,.45)
   f.tube(face,.09,.035,Vector3.ZERO,f.STEEL,Vector3(PI/2,0,0))
   f.tube(face,.073,.005,Vector3(0,0,.021),WARM,Vector3(PI/2,0,0))
   var needle=BoxMesh.new();needle.size=Vector3(.008,.09,.006)
   f.part(face,needle,Vector3(0,.015,.027),f.DARK,Vector3(0,0,-.5+n*.4));face.free()
   for x in [-.9,.9]:
    for z in [-.4,.4]:f.tube(p,.027,.03,Vector3(x,.25,z),f.PALE)
  "cart":
   f.box(p,Vector3(.25,.035,.18),Vector3(.13,.85,.03),BLUE)
   f.box(p,Vector3(.22,.008,.15),Vector3(.13,.875,.03),WARM)
   for i in range(3):f.tube(p,.025,.1,Vector3(-.17+i*.08,.88,.12),f.PALE)
static func wall_unit(f,kind:String,at:Vector3,angle:float)->void:
 var p=Node3D.new();f.add_child(p);p.position=at;p.rotation.y=deg_to_rad(angle)
 match kind:
  "extinguisher":
   f.tube(p,.09,.46,Vector3(0,.97,0),f.RED)
   f.soft(p,Vector3(.18,.14,.18),Vector3(0,1.23,0),f.RED)
   f.box(p,Vector3(.16,.035,.08),Vector3(0,1.31,0),f.DARK)
   f.tube(p,.017,.31,Vector3(.1,1.05,.03),RUBBER)
   f.box(p,Vector3(.09,.18,.01),Vector3(0,.96,.094),WARM)
  "vent":
   f.box(p,Vector3(.75,.45,.035),Vector3(0,2.05,0),f.STEEL)
   for i in range(7):f.box(p,Vector3(.65,.02,.015),Vector3(0,1.88+i*.055,.025),f.DARK)
  "first_aid":
   f.box(p,Vector3(.48,.45,.12),Vector3(0,1.4,0),WARM)
   f.box(p,Vector3(.21,.055,.012),Vector3(0,1.4,.068),f.RED)
   f.box(p,Vector3(.055,.21,.012),Vector3(0,1.4,.07),f.RED)
  "pegboard":
   f.box(p,Vector3(1.2,.65,.04),Vector3(0,1.4,0),BLUE)
   for i in range(5):
    f.tube(p,.012,.22+i*.025,Vector3(-.4+i*.2,1.4,.04),f.STEEL)
    f.ring(p,.025,.04,Vector3(-.4+i*.2,1.55,.04),f.STEEL,Vector3(PI/2,0,0))
 p.free()
static func room_details(f)->void:
 for spec in [["extinguisher",Vector3(-22,0,-10.6),0],["first_aid",Vector3(-30,0,5.5),180],["vent",Vector3(-31,0,-10.6),0],["vent",Vector3(4,0,-12.9),0],["vent",Vector3(16,0,-12.9),0],["extinguisher",Vector3(-4,0,10.6),180],["extinguisher",Vector3(26.2,0,10.9),180],["pegboard",Vector3(18.8,0,10.7),180],["pegboard",Vector3(17.5,0,4.6),0],["first_aid",Vector3(32.8,0,-3),-90]]:
  wall_unit(f,spec[0],spec[1],spec[2])
 f.set_meta("wall_detail_groups",10)
