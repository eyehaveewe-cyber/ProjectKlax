/**
 * Xenalesium low-poly actor meshes. +Y is up; +Z is the actor's forward direction.
 * Vertices are LOCAL to pivot. Records sharing a name form one animated joint.
 * No material, renderer, DOM, or runtime dependencies are required.
 */
export type Vec3 = [number, number, number];
export type MeshPart = {
  name: string;
  vertices: Vec3[];
  triangles: [number, number, number][];
  color: string;
  pivot?: Vec3;
};

/** Seeded hues keep every slime variation pink and every plant variation leafy. */
export function dogPalette(kind:'plant'|'slime',variant:number){
  const n=((variant%8)+8)%8,h=(kind==='slime'?322+n*3:76+n*6)/360;
  const hex=(light:number)=>{
    const sat=kind==='slime'?.68:.46,a=sat*Math.min(light,1-light);
    const channel=(offset:number)=>{const k=(offset+h*12)%12;return Math.round((light-a*Math.max(-1,Math.min(k-3,9-k,1)))*255).toString(16).padStart(2,'0');};
    return '#'+channel(0)+channel(8)+channel(4);
  };
  const light=kind==='slime'?.6:.36;
  return{body:hex(light),light:hex(light+.13),dark:hex(light-.12)};
}

type Triangle = [number, number, number];
type Geometry = { vertices: Vec3[]; triangles: Triangle[] };
type Ring = { x: number; y: number; z: number; w: number; d: number };

const IVORY = "#C9D0C7";
const STEEL = "#84949A";
const STEEL_LIGHT = "#E0E5D9";
const TEAL = "#245E65";
const TEAL_DARK = "#193C44";
const LEATHER = "#352F2C";
const CRIMSON = "#8F2833";
const GOLD = "#AD9761";
const OLIVE = "#788044";
const OLIVE_LIGHT = "#949559";
const OLIVE_DARK = "#505A36";
const RUST = "#866046";
const IRON = "#686E6C";

const chamfer: [number, number][] = [
  [-0.6, -1], [0.6, -1], [1, -0.6], [1, 0.6],
  [0.6, 1], [-0.6, 1], [-1, 0.6], [-1, -0.6],
];
const square: [number, number][] = [[-1, -1], [1, -1], [1, 1], [-1, 1]];

const add = (a: Vec3, b: Vec3): Vec3 => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
const sub = (a: Vec3, b: Vec3): Vec3 => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const mul = (a: Vec3, s: number): Vec3 => [a[0] * s, a[1] * s, a[2] * s];
const cross = (a: Vec3, b: Vec3): Vec3 => [
  a[1] * b[2] - a[2] * b[1],
  a[2] * b[0] - a[0] * b[2],
  a[0] * b[1] - a[1] * b[0],
];
const unit = (v: Vec3): Vec3 => mul(v, 1 / (Math.hypot(...v) || 1));

function merge(...pieces: Geometry[]): Geometry {
  const vertices: Vec3[] = [];
  const triangles: Triangle[] = [];
  for (const piece of pieces) {
    const offset = vertices.length;
    vertices.push(...piece.vertices);
    triangles.push(...piece.triangles.map(([a, b, c]): Triangle => [a + offset, b + offset, c + offset]));
  }
  return { vertices, triangles };
}

export function part(name: string, color: string, pivot: Vec3, ...pieces: Geometry[]): MeshPart {
  const geometry = merge(...pieces);
  return {
    name, color, pivot: [...pivot],
    vertices: geometry.vertices.map(v => sub(v, pivot)),
    triangles: geometry.triangles,
  };
}

/** Closed faceted loft; all ring locations are in actor coordinates. */
export function loft(rings: Ring[], outline = chamfer): Geometry {
  const vertices: Vec3[] = rings.flatMap(r => outline.map(([x, z]): Vec3 => [r.x + x * r.w, r.y, r.z + z * r.d]));
  const triangles: Triangle[] = [];
  const n = outline.length;
  for (let r = 0; r < rings.length - 1; r++) {
    for (let i = 0; i < n; i++) {
      const j = (i + 1) % n;
      const a = r * n + i, b = r * n + j, c = (r + 1) * n + j, d = (r + 1) * n + i;
      triangles.push([a, b, c], [a, c, d]);
    }
  }
  for (let i = 1; i < n - 1; i++) {
    triangles.push([0, i + 1, i]);
    const end = (rings.length - 1) * n;
    triangles.push([end, end + i, end + i + 1]);
  }
  return { vertices, triangles };
}

/** Tapered limb with a square or hexagonal cross section, never a scaled cube. */
export function limb(a: Vec3, b: Vec3, ra: number, rb: number, depth: number, sides = 4): Geometry {
  const direction = unit(sub(b, a));
  const u = unit(cross(direction, Math.abs(direction[2]) > 0.9 ? [0, 1, 0] : [0, 0, 1]));
  const v = unit(cross(direction, u));
  const vertices: Vec3[] = [];
  for (const [center, radius] of [[a, ra], [b, rb]] as [Vec3, number][]) {
    for (let i = 0; i < sides; i++) {
      const angle = (i / sides) * Math.PI * 2 + Math.PI / 4;
      vertices.push(add(center, add(mul(u, Math.cos(angle) * radius), mul(v, Math.sin(angle) * depth))));
    }
  }
  const triangles: Triangle[] = [];
  for (let i = 0; i < sides; i++) {
    const j = (i + 1) % sides;
    triangles.push([i, j, sides + j], [i, sides + j, sides + i]);
  }
  for (let i = 1; i < sides - 1; i++) {
    triangles.push([0, i + 1, i], [sides, sides + i, sides + i + 1]);
  }
  return { vertices, triangles };
}

/** Extrude a clockwise XY silhouette between the supplied back and front Z. */
export function prism(points: [number, number][], back: number, front: number): Geometry {
  const n = points.length;
  const vertices = [back, front].flatMap(z => points.map(([x, y]): Vec3 => [x, y, z]));
  const triangles: Triangle[] = [];
  for (let i = 1; i < n - 1; i++) triangles.push([0, i + 1, i], [n, n + i, n + i + 1]);
  for (let i = 0; i < n; i++) {
    const j = (i + 1) % n;
    triangles.push([i, j, n + j], [i, n + j, n + i]);
  }
  return { vertices, triangles };
}

export function box(center: Vec3, size: Vec3): Geometry {
  const [x, y, z] = center, [w, h, d] = size.map(n => n / 2);
  return prism([[x - w, y - h], [x + w, y - h], [x + w, y + h], [x - w, y + h]], z - d, z + d);
}

export function surface(vertices: Vec3[], triangles?: Triangle[]): Geometry {
  return { vertices, triangles: triangles ?? vertices.slice(2).map((_, i): Triangle => [0, i + 1, i + 2]) };
}

export function pyramid(base: Vec3[], tip: Vec3): Geometry {
  const vertices = [...base, tip];
  const n = base.length;
  const triangles: Triangle[] = [];
  for (let i = 0; i < n; i++) triangles.push([i, (i + 1) % n, n]);
  for (let i = 1; i < n - 1; i++) triangles.push([0, i + 1, i]);
  return { vertices, triangles };
}

function xyMirror(g: Geometry, sign: number): Geometry {
  return { vertices: g.vertices.map(([x, y, z]): Vec3 => [sign * x, y, z]), triangles: g.triangles.map(t => [...t]) };
}

export function createMonkParts():MeshPart[]{
  const skin='#b98764',cloth='#d6af64',sash='#804637',torso:Vec3=[0,1.02,0],head:Vec3=[0,1.49,.015];
  const parts:MeshPart[]=[
    part('torso',cloth,torso,loft([{x:0,y:.77,z:0,w:.22,d:.15},{x:0,y:1.08,z:0,w:.2,d:.14},{x:0,y:1.4,z:0,w:.26,d:.15}])),
    part('torso','#f0d5a0',torso,prism([[-.25,1.4],[-.07,1.43],[.22,1.05],[.08,.96]],.153,.17)),
    part('torso',sash,torso,box([0,1.01,0],[.45,.09,.33]),prism([[.05,1.04],[.15,1.01],[.17,.58],[.06,.62]],.17,.19)),
    part('head',skin,head,loft([{x:0,y:1.48,z:.02,w:.11,d:.11},{x:0,y:1.64,z:.02,w:.15,d:.14},{x:0,y:1.77,z:0,w:.08,d:.09}])),
    part('head','#44362e',head,loft([{x:0,y:1.7,z:-.02,w:.13,d:.12},{x:0,y:1.8,z:-.05,w:.075,d:.07},{x:0,y:1.87,z:-.05,w:.04,d:.04}])),
    part('head','#302821',head,box([-.065,1.64,.162],[.045,.018,.012]),box([.065,1.64,.162],[.045,.018,.012])),
    part('head','#d09b76',head,pyramid([[-.022,1.64,.16],[.022,1.64,.16],[.018,1.58,.16],[-.018,1.58,.16]],[0,1.59,.2])),
    part('head',sash,head,box([0,1.55,.151],[.07,.014,.015])),
  ];
  for(const sign of [-1,1]){
    const arm:Vec3=[sign*.27,1.37,0],leg:Vec3=[sign*.13,.84,0],an=sign<0?'leftArm':'rightArm',ln=sign<0?'leftLeg':'rightLeg';
    parts.push(part(an,skin,arm,limb(arm,[sign*.37,1.13,.025],.09,.07,.08),limb([sign*.37,1.13,.025],[sign*.41,.97,.17],.07,.055,.07),box([sign*.41,.95,.18],[.105,.12,.11])),
      part(an,'#eee0bd',arm,limb([sign*.385,1.08,.09],[sign*.41,.98,.16],.073,.064,.075)),
      part(ln,cloth,leg,limb(leg,[sign*.15,.42,0],.13,.085,.12)),
      part(ln,'#eee0bd',leg,limb([sign*.15,.42,0],[sign*.16,.13,.045],.09,.075,.08)),
      part(ln,'#513b2b',leg,box([sign*.16,.055,.07],[.2,.1,.31])));
  }
  const hand:Vec3=[.41,.95,.18];
  parts.push(part('staff','#8c603d',hand,limb([.41,.38,-.42],[.41,1.6,.83],.036,.036,.036,6)),
    part('staff','#e4c17f',hand,limb([.41,.35,-.45],[.41,.49,-.31],.05,.05,.05,6),limb([.41,1.47,.7],[.41,1.63,.86],.05,.05,.05,6)));
  return parts;
}

export function createWizardParts():MeshPart[]{
  const torso:Vec3=[0,.65,0],head:Vec3=[0,.98,.09],hand:Vec3=[.405,.605,.18];
  const parts=createGoblinParts().filter(p=>p.name!=='sword'&&p.name!=='torso');
  parts.push(part('torso','#514b7d',torso,loft([{x:0,y:.12,z:0,w:.34,d:.24},{x:0,y:.65,z:.015,w:.18,d:.14},{x:0,y:.98,z:.04,w:.25,d:.17}])),
    part('torso','#d9bd75',torso,box([0,.64,.025],[.4,.06,.34])),
    part('head','#62558d',head,loft([{x:0,y:1.29,z:.02,w:.29,d:.22},{x:0,y:1.36,z:.02,w:.23,d:.18},{x:.08,y:1.91,z:-.04,w:.005,d:.005}])),
    part('head','#d9bd75',head,loft([{x:0,y:1.36,z:.02,w:.23,d:.182},{x:.012,y:1.41,z:.015,w:.207,d:.162}])),
    part('staff','#8b7150',hand,limb([.405,.08,.18],[.405,1.55,.18],.04,.035,.04,6)),
    part('staff','#a7e8ff',hand,loft([{x:.405,y:1.48,z:.18,w:.02,d:.02},{x:.405,y:1.65,z:.18,w:.12,d:.12},{x:.405,y:1.87,z:.18,w:0,d:0}])));
  return parts;
}

/** Pointed ears, cheek tufts, long muzzle and curled tail from the supplied dogs. */
export function createDogParts(kind:'plant'|'slime',variant=0):MeshPart[]{
  const c=dogPalette(kind,variant),torso:Vec3=[0,.64,-.06],head:Vec3=[0,.99,.44],parts:MeshPart[]=[];
  parts.push(part('torso',c.body,torso,loft([{x:0,y:.4,z:-.06,w:.25,d:.52},{x:0,y:.65,z:-.06,w:.37,d:.64},{x:0,y:.9,z:.03,w:.29,d:.51}])),
    part('head',c.light,head,loft([{x:0,y:.76,z:.43,w:.2,d:.22},{x:0,y:1.04,z:.44,w:.31,d:.29},{x:0,y:1.23,z:.42,w:.2,d:.18}])),
    part('head',c.body,head,loft([{x:0,y:.82,z:.76,w:.17,d:.17},{x:0,y:.97,z:.77,w:.21,d:.21},{x:0,y:1.05,z:.74,w:.13,d:.16}])),
    part('head','#263025',head,loft([{x:0,y:.98,z:.94,w:.075,d:.035},{x:0,y:1.055,z:.94,w:.06,d:.035}])),
    part('head','#382938',head,box([0,.848,.86],[.22,.038,.15])),
    part('head','#ef8bb5',head,prism([[-.07,.865],[.07,.865],[.055,.74],[-.045,.72]],.887,.935)));
  for(const sign of [-1,1]){
    parts.push(part('head',c.body,head,prism([[sign*.08,1.16],[sign*.32,1.14],[sign*.275,1.56]],.32,.49)),
      part('head',c.dark,head,surface([[sign*.13,1.2,.492],[sign*.28,1.2,.492],[sign*.26,1.46,.492]])),
      part('eyes','#252827',head,loft([{x:sign*.145,y:1.06,z:.717,w:.068,d:.035},{x:sign*.145,y:1.15,z:.711,w:.063,d:.035}])),
      part('eyes','#eaf2df',head,box([sign*.13,1.128,.756],[.022,.025,.014])));
    for(const z of[-.43,.36]){
      const joint:Vec3=[sign*.27,.56,z],name=sign<0?'leftLeg':'rightLeg';
      parts.push(part(name,c.body,joint,limb(joint,[sign*.3,.2,z+.015],.105,.08,.1,6),loft([{x:sign*.3,y:.06,z:z+.08,w:.13,d:.18},{x:sign*.3,y:.2,z:z+.03,w:.095,d:.12}])));
    }
  }
  // Tufts are volumetric pointed leaves or gel drips, each attached to the body.
  for(let i=0;i<20;i++){
    const a=i*2.399,side=Math.sin(a),front=Math.cos(a),y=.47+(i%4)*.14,z=-.08+front*.45,x=side*.29;
    parts.push(part('torso',i%3?c.body:c.light,torso,pyramid([[x-.09,y+.09,z-.04],[x+.09,y+.09,z-.04],[x+.07,y+.02,z+.075],[x-.07,y+.02,z+.075]],[x+side*.16,y-(kind==='plant'?.18:.12),z+front*.14])));
  }
  for(let i=0;i<6;i++){const sign=i%2?-1:1,y=.98+(i%3)*.095;
    parts.push(part('head',i%2?c.light:c.body,head,pyramid([[sign*.2,y+.06,.48],[sign*.29,y+.03,.5],[sign*.23,y-.06,.62]],[sign*.39,y-.16,.6])));
  }
  const tail:Vec3=[0,.68,-.59];parts.push(part('tail',c.body,tail,limb(tail,[.19,.88,-.77],.13,.11,.13,6),limb([.19,.88,-.77],[.12,1.16,-.63],.12,.1,.11,6),limb([.12,1.16,-.63],[-.14,1.01,-.5],.12,.03,.12,6)));
  if(kind==='plant'){
    for(let i=0;i<6;i++){const a=i*Math.PI/3;parts.push(part('roots',c.dark,[0,0,0],limb([0,.45,0],[Math.sin(a)*.65,.04,Math.cos(a)*.65],.15,.035,.12,5)));}
    for(let i=0;i<5;i++){const a=i*2.1;parts.push(part('head',c.light,head,pyramid([[Math.sin(a)*.12,1.18,.36],[Math.sin(a)*.12+.15,1.17,.41],[Math.sin(a)*.12,1.18,.52]],[Math.sin(a)*.2,1.48+(i%2)*.18,.24])));}
  }else{
    for(let i=0;i<7;i++){const a=i*2.4;parts.push(part('cubes',i%2?c.body:c.light,[0,0,0],box([Math.sin(a)*.43,.1+(i%3)*.1,Math.cos(a)*.43],[.23+(i%2)*.08,.22,.24])));}
    parts.push(part('head','#ffdeee',head,surface([[-.2,1.15,.64],[-.1,1.2,.69],[-.15,1.1,.7]])),part('torso','#ffdeee',torso,surface([[.28,.7,.13],[.22,.8,.24],[.3,.61,.27]])));
  }
  return parts;
}

export function createDryadParts():MeshPart[]{
  const head:Vec3=[0,1.49,.015],torso:Vec3=[0,1.02,0];
  const parts=createMonkParts().filter(p=>p.name!=='staff').map(p=>({...p,color:p.color==='#b98764'?'#826646':p.color==='#d6af64'?'#5b794b':p.color==='#44362e'?'#45623d':p.color}));
  for(const sign of[-1,1]){
    parts.push(part('head','#715b3d',head,limb([sign*.1,1.72,0],[sign*.24,2.13,-.05],.045,.02,.05,5),limb([sign*.2,2,-.04],[sign*.45,2.13,.02],.025,.01,.025,5)),
      part('head','#a0bf6c',head,pyramid([[sign*.22,1.99,-.03],[sign*.29,2.03,-.05],[sign*.28,2.09,.03]],[sign*.49,2.23,.05])),
      part('torso','#4e663e',torso,pyramid([[sign*.12,1.28,.17],[sign*.24,1.23,.17],[sign*.19,1.03,.18]],[sign*.25,1.47,.2])));
  }
  return parts;
}

export function createSpiderParts():MeshPart[]{
  const root:Vec3=[0,.4,0],parts=[part('torso','#624970',root,loft([{x:0,y:.2,z:-.27,w:.18,d:.3},{x:0,y:.48,z:-.27,w:.36,d:.48},{x:0,y:.68,z:-.28,w:.19,d:.29}])),part('head','#967ab0',root,loft([{x:0,y:.25,z:.28,w:.14,d:.14},{x:0,y:.5,z:.28,w:.25,d:.23},{x:0,y:.61,z:.28,w:.12,d:.13}]))];
  for(const sign of[-1,1])for(let i=0;i<4;i++){const z=-.36+i*.22,pivot:Vec3=[sign*.22,.43,z],knee:Vec3=[sign*(.72+Math.sin(i)*.1),.55,z+(i-1.5)*.2],foot:Vec3=[sign*.87,.025,z+(i-1.5)*.3];parts.push(part(sign<0?'leftLeg':'rightLeg','#44374f',pivot,limb(pivot,knee,.036,.025,.035,4),limb(knee,foot,.025,.015,.025,4)));}
  for(const x of[-.12,-.04,.04,.12])parts.push(part('head','#f0c99a',root,box([x,.47,.507],[.036,.04,.021])));
  return parts;
}

export function createOctopusParts():MeshPart[]{
  const root:Vec3=[0,.6,0],parts=[part('torso','#958cba',root,loft([{x:0,y:.28,z:0,w:.27,d:.25},{x:0,y:.72,z:0,w:.4,d:.37},{x:0,y:1.15,z:-.04,w:.23,d:.21},{x:0,y:1.27,z:-.05,w:.04,d:.04}]))];
  for(let i=0;i<8;i++){const a=i*Math.PI/4,start:Vec3=[Math.sin(a)*.19,.42,Math.cos(a)*.19],bend:Vec3=[Math.sin(a)*.5,.12,Math.cos(a)*.5],tip:Vec3=[Math.sin(a+.18)*.9,.05,Math.cos(a+.18)*.9];parts.push(part(i%2?'leftLeg':'rightLeg','#786e9f',start,limb(start,bend,.11,.08,.11,6),limb(bend,tip,.08,.03,.08,6)));parts.push(part('torso','#c4acbd',root,box([bend[0],.15,bend[2]],[.08,.08,.08])));}
  for(const sign of[-1,1])parts.push(part('head','#292638',root,box([sign*.16,.81,.345],[.12,.09,.03])),part('head','#eee1a8',root,box([sign*.16,.82,.365],[.032,.075,.012])));
  return parts;
}

export function createHumanEnemyParts(cultist=false):MeshPart[]{
  const parts=createMonkParts().filter(p=>p.name!=='staff').map(p=>({...p,color:p.name==='head'?p.color:p.color==='#d6af64'?(cultist?'#405b72':'#745f48'):p.color==='#eee0bd'?'#788681':p.color}));
  parts.push(...createWarriorParts().filter(p=>p.name==='sword'));
  if(cultist)parts.push(part('head','#293d50',[0,1.49,.015],loft([{x:0,y:1.48,z:-.04,w:.2,d:.19},{x:0,y:1.77,z:-.06,w:.15,d:.15},{x:0,y:1.88,z:-.09,w:.03,d:.04}])));
  return parts;
}

/**
 * 1.80 m warrior, planted stance; shoulders at 1.39 m and hips at 0.84 m.
 * Sword points ahead from the right hand. Rotate sword around its hand pivot.
 */
export function createWarriorParts(): MeshPart[] {
  const torso: Vec3 = [0, 1.03, 0];
  const head: Vec3 = [0, 1.49, 0.015];
  const leftArm: Vec3 = [-0.285, 1.39, 0];
  const rightArm: Vec3 = [0.285, 1.39, 0];
  const leftLeg: Vec3 = [-0.135, 0.84, 0];
  const rightLeg: Vec3 = [0.135, 0.84, 0];
  const rightHand: Vec3 = [0.42, 0.97, 0.16];
  const leftHand: Vec3 = [-0.42, 0.97, 0.16];
  const parts: MeshPart[] = [
    part("torso", IVORY, torso, loft([
      { x: 0, y: 1.00, z: 0, w: 0.205, d: 0.125 },
      { x: 0, y: 1.29, z: 0, w: 0.285, d: 0.17 },
      { x: 0, y: 1.45, z: -0.015, w: 0.255, d: 0.135 },
    ])),
    part("torso", TEAL_DARK, torso, loft([
      { x: 0, y: 0.80, z: 0, w: 0.20, d: 0.13 },
      { x: 0, y: 1.025, z: 0, w: 0.19, d: 0.13 },
    ], square)),
    part("torso", TEAL, torso, surface([
      [-0.13, 1.395, 0.161], [0.13, 1.395, 0.161], [0.095, 1.13, 0.166],
      [0, 1.06, 0.146], [-0.095, 1.13, 0.166],
    ])),
    part("torso", LEATHER, torso, box([0, 1.01, 0], [0.43, 0.075, 0.28])),
    part("torso", GOLD, torso, box([0, 1.013, 0.15], [0.073, 0.072, 0.025])),
    part("torso", CRIMSON, torso, loft([
      { x: 0, y: 1.435, z: 0, w: 0.145, d: 0.13 },
      { x: 0, y: 1.515, z: 0, w: 0.12, d: 0.105 },
    ]), prism([[-0.105, 1.47], [-0.028, 1.44], [-0.06, 1.20]], 0.16, 0.184)),
    part("head", IVORY, head, loft([
      { x: 0, y: 1.50, z: 0.015, w: 0.118, d: 0.113 },
      { x: 0, y: 1.69, z: 0.005, w: 0.151, d: 0.143 },
      { x: 0, y: 1.785, z: -0.005, w: 0.080, d: 0.092 },
    ])),
    part("head", "#202D34", head, surface([
      [-0.12, 1.685, 0.139], [0.12, 1.685, 0.139], [0.115, 1.604, 0.146],
      [0, 1.577, 0.162], [-0.115, 1.604, 0.146],
    ])),
    part("head", "#A6CBC2", head, surface([
      [-0.103, 1.653, 0.150], [-0.027, 1.65, 0.150], [-0.031, 1.632, 0.153], [-0.096, 1.631, 0.153],
    ]), surface([
      [0.027, 1.65, 0.150], [0.103, 1.653, 0.150], [0.096, 1.631, 0.153], [0.031, 1.632, 0.153],
    ])),
    part("head", STEEL_LIGHT, head, prism([[-0.023, 1.695], [0.023, 1.695], [0, 1.80]], -0.082, 0.102)),
  ];

  for (const sign of [-1, 1]) {
    const armName = sign < 0 ? "leftArm" : "rightArm";
    const armPivot = sign < 0 ? leftArm : rightArm;
    const legName = sign < 0 ? "leftLeg" : "rightLeg";
    const legPivot = sign < 0 ? leftLeg : rightLeg;
    parts.push(
      part(armName, LEATHER, armPivot,
        limb([sign * 0.285, 1.35, 0], [sign * 0.36, 1.15, 0.045], 0.095, 0.072, 0.09),
        box([sign * 0.415, 0.97, 0.155], [0.105, 0.115, 0.115])),
      part(armName, STEEL, armPivot,
        limb([sign * 0.36, 1.14, 0.045], [sign * 0.415, 1.01, 0.14], 0.105, 0.081, 0.085)),
      part(armName, IVORY, armPivot, xyMirror(prism([
        [0.21, 1.375], [0.35, 1.315], [0.425, 1.405], [0.30, 1.46],
      ], -0.113, 0.114), sign)),
      part(legName, LEATHER, legPivot,
        limb([sign * 0.13, 0.84, 0], [sign * 0.155, 0.46, 0.015], 0.12, 0.09, 0.13)),
      part(legName, STEEL, legPivot,
        limb([sign * 0.155, 0.46, 0.015], [sign * 0.16, 0.12, 0.035], 0.102, 0.08, 0.09)),
      part(legName, TEAL_DARK, legPivot, xyMirror(prism([
        [0.072, 0], [0.253, 0], [0.247, 0.135], [0.105, 0.18],
      ], -0.07, 0.224), sign)),
    );
  }

  // Raised forward blade with four bevel faces, a narrow distal section, and a diamond tip.
  const blade: Geometry = {
    vertices: [
      [0.365, 0.98, 0.31], [0.42, 0.998, 0.296], [0.475, 0.98, 0.31], [0.42, 0.962, 0.324],
      [0.383, 1.47, 0.90], [0.42, 1.485, 0.888], [0.457, 1.47, 0.90], [0.42, 1.455, 0.912],
      [0.42, 1.59, 1.04], [0.42, 0.974, 0.24],
    ],
    triangles: [
      [0, 1, 5], [0, 5, 4], [1, 2, 6], [1, 6, 5], [2, 3, 7], [2, 7, 6], [3, 0, 4], [3, 4, 7],
      [4, 5, 8], [5, 6, 8], [6, 7, 8], [7, 4, 8],
      [0, 9, 1], [1, 9, 2], [2, 9, 3], [3, 9, 0],
    ],
  };
  parts.push(
    part("sword", STEEL_LIGHT, rightHand, blade),
    part("sword", GOLD, rightHand, box([0.42, 0.979, 0.26], [0.27, 0.05, 0.055])),
    part("sword", LEATHER, rightHand, box([0.42, 0.974, 0.139], [0.052, 0.052, 0.19])),
    part("sword", STEEL, rightHand, pyramid([
      [0.39, 0.944, 0.05], [0.45, 0.944, 0.05], [0.45, 1.004, 0.05], [0.39, 1.004, 0.05],
    ], [0.42, 0.974, 0.005])),
    part("shield", TEAL, leftHand, prism([
      [-0.655, 1.28], [-0.42, 1.34], [-0.185, 1.28], [-0.235, 0.98], [-0.42, 0.765], [-0.605, 0.98],
    ], 0.213, 0.28)),
    part("shield", IVORY, leftHand, surface([
      [-0.594, 1.231, 0.281], [-0.42, 1.276, 0.281], [-0.247, 1.231, 0.281],
      [-0.286, 1.013, 0.281], [-0.42, 0.846, 0.281], [-0.554, 1.013, 0.281],
    ])),
    part("shield", TEAL_DARK, leftHand, surface([
      [-0.42, 1.20, 0.283], [-0.365, 1.09, 0.283], [-0.42, 0.94, 0.283], [-0.475, 1.09, 0.283],
    ])),
    part("cape", TEAL_DARK, [0, 1.46, -0.14], surface([
      [-0.225, 1.435, -0.17], [0.225, 1.435, -0.17], [0.30, 0.98, -0.24],
      [0.245, 0.685, -0.30], [0, 0.72, -0.34], [-0.245, 0.685, -0.30], [-0.30, 0.98, -0.24],
    ], [[0, 1, 4], [1, 2, 4], [2, 3, 4], [0, 4, 6], [6, 4, 5]])),
  );
  return parts;
}

/** 1.31 m goblin with an oversized head, a hunched chest, and 0.99 m ear span. */
export function createGoblinParts(armored = false): MeshPart[] {
  const torso: Vec3 = [0, 0.65, 0];
  const head: Vec3 = [0, 0.98, 0.09];
  const leftArm: Vec3 = [-0.255, 0.915, 0.03];
  const rightArm: Vec3 = [0.255, 0.915, 0.03];
  const leftLeg: Vec3 = [-0.12, 0.49, 0];
  const rightLeg: Vec3 = [0.12, 0.49, 0];
  const hand: Vec3 = [0.405, 0.605, 0.18];
  const parts: MeshPart[] = [
    part("torso", OLIVE, torso, loft([
      { x: 0, y: 0.49, z: 0, w: 0.165, d: 0.13 },
      { x: 0, y: 0.72, z: 0.055, w: 0.24, d: 0.185 },
      { x: 0, y: 0.96, z: 0.045, w: 0.225, d: 0.15 },
    ])),
    part("torso", LEATHER, torso, box([0, 0.58, 0.018], [0.425, 0.082, 0.31]),
      prism([[-0.165, 0.566], [0.165, 0.566], [0.13, 0.35], [-0.12, 0.33]], 0.145, 0.17)),
    part("torso", "#675137", torso, surface([
      [-0.20, 0.89, 0.179], [-0.135, 0.935, 0.184], [0.155, 0.645, 0.215], [0.09, 0.62, 0.221],
    ])),
    part("torso", RUST, torso, box([0.012, 0.586, 0.188], [0.068, 0.077, 0.027])),
    part("head", OLIVE_LIGHT, head, loft([
      { x: 0, y: 0.99, z: 0.10, w: 0.145, d: 0.13 },
      { x: 0, y: 1.19, z: 0.074, w: 0.205, d: 0.168 },
      { x: 0, y: 1.31, z: 0.048, w: 0.13, d: 0.113 },
    ])),
    part("head", OLIVE, head, prism([
      [-0.13, 1.107], [0.13, 1.107], [0.10, 0.982], [-0.08, 0.976],
    ], 0.18, 0.285)),
    part("head", OLIVE_DARK, head, pyramid([
      [-0.075, 1.14, 0.253], [0.075, 1.14, 0.253], [0, 1.218, 0.247],
    ], [0, 1.10, 0.352]), surface([
      [-0.088, 1.036, 0.288], [0.091, 1.036, 0.288], [0.061, 1.012, 0.290], [-0.071, 1.012, 0.290],
    ])),
    part("head", "#D6C793", head, pyramid([
      [-0.108, 1.012, 0.286], [-0.064, 1.012, 0.299], [-0.087, 0.998, 0.324],
    ], [-0.10, 1.109, 0.335]), pyramid([
      [0.064, 1.012, 0.299], [0.108, 1.012, 0.286], [0.087, 0.998, 0.324],
    ], [0.10, 1.109, 0.335])),
  ];

  for (const sign of [-1, 1]) {
    const armName = sign < 0 ? "leftArm" : "rightArm";
    const armPivot = sign < 0 ? leftArm : rightArm;
    const legName = sign < 0 ? "leftLeg" : "rightLeg";
    const legPivot = sign < 0 ? leftLeg : rightLeg;
    parts.push(
      part("head", OLIVE, head, xyMirror(prism([
        [0.155, 1.255], [0.495, 1.295], [0.34, 1.087], [0.167, 1.10],
      ], 0.025, 0.078), sign)),
      part("head", "#9D7859", head, xyMirror(surface([
        [0.192, 1.226, 0.079], [0.426, 1.265, 0.079], [0.32, 1.129, 0.079],
      ]), sign)),
      part("head", "#222C23", head, xyMirror(surface([
        [0.035, 1.181, 0.238], [0.165, 1.196, 0.207], [0.145, 1.14, 0.225], [0.049, 1.142, 0.248],
      ]), sign)),
      part("head", "#E4BD4D", head, xyMirror(surface([
        [0.061, 1.172, 0.251], [0.134, 1.18, 0.233], [0.117, 1.151, 0.244], [0.066, 1.153, 0.255],
      ]), sign)),
      part("head", OLIVE_DARK, head, xyMirror(surface([
        [0.021, 1.192, 0.244], [0.171, 1.218, 0.212], [0.164, 1.194, 0.229], [0.035, 1.176, 0.252],
      ]), sign)),
      part(armName, OLIVE, armPivot,
        limb([sign * 0.25, 0.915, 0.03], [sign * 0.355, 0.742, 0.055], 0.106, 0.076, 0.105),
        limb([sign * 0.355, 0.742, 0.055], [sign * 0.405, 0.635, 0.17], 0.089, 0.062, 0.087),
        box([sign * 0.405, 0.606, 0.182], [0.115, 0.095, 0.142])),
      part(armName, LEATHER, armPivot, xyMirror(prism([
        [0.297, 0.802], [0.399, 0.783], [0.439, 0.705], [0.346, 0.715],
      ], 0.02, 0.127), sign)),
      part(legName, OLIVE_DARK, legPivot,
        limb([sign * 0.12, 0.49, 0.01], [sign * 0.158, 0.255, 0.016], 0.098, 0.08, 0.103)),
      part(legName, OLIVE, legPivot,
        limb([sign * 0.158, 0.255, 0.016], [sign * 0.164, 0.071, 0.07], 0.078, 0.061, 0.072),
        xyMirror(prism([[0.08, 0], [0.257, 0], [0.25, 0.064], [0.128, 0.117]], -0.029, 0.24), sign)),
    );
    if (armored) {
      parts.push(part(armName, IRON, armPivot, xyMirror(prism([
        [0.184, 0.91], [0.304, 0.864], [0.399, 0.94], [0.257, 1.022],
      ], -0.076, 0.157), sign)));
    }
  }

  // A top-heavy rusty cleaver, held ahead of the right fist.
  parts.push(
    part("sword", RUST, hand, prism([
      [0.365, 0.753], [0.532, 1.135], [0.688, 1.092], [0.665, 0.791], [0.443, 0.707],
    ], 0.247, 0.29)),
    part("sword", "#B0AAA0", hand, surface([
      [0.532, 1.135, 0.291], [0.688, 1.092, 0.291], [0.665, 0.791, 0.291],
      [0.628, 0.819, 0.292], [0.648, 1.061, 0.292],
    ])),
    part("sword", LEATHER, hand, limb([0.39, 0.56, 0.18], [0.431, 0.774, 0.264], 0.042, 0.04, 0.038)),
  );
  if (armored) {
    parts.push(part("head", IRON, head, loft([
      { x: 0, y: 1.24, z: 0.045, w: 0.178, d: 0.139 },
      { x: 0, y: 1.348, z: 0.041, w: 0.084, d: 0.083 },
    ])), part("head", "#969A8D", head, prism([[-0.022, 1.26], [0.022, 1.26], [0, 1.365]], -0.062, 0.168)));
  }
  return parts;
}

/** Bat: 1.34 m wing span, body 0.34 m tall. Wing pivots are the shoulder roots. */
export function createBatParts(): MeshPart[] {
  const body: Vec3 = [0, 0.17, 0];
  const head: Vec3 = [0, 0.26, 0.037];
  const hexagon: [number, number][] = Array.from({ length: 6 }, (_, i) => [Math.cos(i * Math.PI / 3), Math.sin(i * Math.PI / 3)]);
  const parts: MeshPart[] = [
    part("torso", "#40354B", body, loft([
      { x: 0, y: 0, z: 0, w: 0.035, d: 0.03 },
      { x: 0, y: 0.19, z: 0, w: 0.085, d: 0.06 },
      { x: 0, y: 0.27, z: 0.014, w: 0.055, d: 0.04 },
    ], hexagon)),
    part("head", "#65516B", head, loft([
      { x: 0, y: 0.222, z: 0.054, w: 0.052, d: 0.04 },
      { x: 0, y: 0.31, z: 0.04, w: 0.076, d: 0.057 },
    ], square)),
  ];
  for (const sign of [-1, 1]) {
    const wingName = sign < 0 ? "leftWing" : "rightWing";
    const pivot: Vec3 = [sign * 0.07, 0.22, 0];
    const membrane = xyMirror(surface([
      [0.07, 0.22, 0], [0.23, 0.41, 0.018], [0.67, 0.295, -0.035],
      [0.50, 0.16, -0.08], [0.37, 0.20, -0.058], [0.25, 0.046, -0.105],
      [0.19, 0.139, -0.065], [0.075, 0.102, 0.006],
    ], [[0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 5], [0, 5, 6], [0, 6, 7]]), sign);
    parts.push(
      part(wingName, "#65425C", pivot, membrane),
      part(wingName, "#9A7287", pivot, xyMirror(surface([
        [0.068, 0.223, 0.006], [0.228, 0.42, 0.024], [0.244, 0.397, 0.024],
        [0.662, 0.302, -0.031], [0.637, 0.284, -0.031],
      ], [[0, 1, 2], [1, 3, 4], [1, 4, 2]]), sign)),
      part("head", "#65516B", head, xyMirror(pyramid([
        [0.033, 0.296, 0.017], [0.063, 0.285, 0.058], [0.081, 0.302, 0.01],
      ], [0.09, 0.413, 0.02]), sign)),
      part("head", "#E9A751", head, xyMirror(surface([
        [0.013, 0.281, 0.098], [0.061, 0.283, 0.091], [0.038, 0.264, 0.099],
      ]), sign)),
    );
  }
  return parts;
}

/** Orc handoff silhouette rebuilt as articulated geometry, not billboard sprites. */
export function createBerserkerParts(gender:'male'|'female'='male'):MeshPart[]{
  const female=gender==='female',skin=female?'#367c83':'#bd443b',trim=female?'#c2c6cf':'#c5a04d',cloth='#171820',fur='#514840';
  const torso:Vec3=[0,1.02,0],head:Vec3=[0,1.49,0],width=female?.26:.31;
  const parts:MeshPart[]=[
    part('torso',cloth,torso,loft([{x:0,y:.8,z:0,w:.23,d:.17},{x:0,y:1.1,z:0,w:female?.21:.27,d:.18},{x:0,y:1.4,z:0,w:width,d:.19}])),
    part('torso',trim,torso,box([0,.92,.18],[.48,.065,.035]),box([0,.92,.21],[.1,.11,.05]),box([0,1.37,.2],[.18,.045,.03])),
    part('head',skin,head,loft([{x:0,y:1.44,z:.06,w:.15,d:.15},{x:0,y:1.65,z:.02,w:.2,d:.17},{x:0,y:1.8,z:0,w:.16,d:.14}]),box([0,1.51,.2],[.28,.1,.12])),
    part('head','#24232a',head,box([-.085,1.64,.197],[.09,.027,.025]),box([.085,1.64,.197],[.09,.027,.025])),
    part('head','#ef6250',head,box([-.083,1.626,.214],[.03,.018,.01]),box([.083,1.626,.214],[.03,.018,.01])),
  ];
  for(const sign of [-1,1]){
    const arm:Vec3=[sign*(width+.025),1.36,0],leg:Vec3=[sign*.2,.81,0],an=sign<0?'leftArm':'rightArm',ln=sign<0?'leftLeg':'rightLeg';
    parts.push(part('head',skin,head,pyramid([[sign*.16,1.6,-.02],[sign*.17,1.74,-.02],[sign*.17,1.68,.08]],[sign*.33,1.76,0])),
      part('head','#efe7c9',head,pyramid([[sign*.07,1.5,.27],[sign*.13,1.5,.27],[sign*.1,1.5,.21]],[sign*.1,1.63,.28])),
      part(an,skin,arm,limb(arm,[sign*.41,1.11,.02],.115,.09,.1),limb([sign*.41,1.11,.02],[sign*.46,.94,.18],.09,.065,.085),box([sign*.46,.93,.19],[.16,.14,.17])),
      part(an,cloth,arm,limb([sign*.44,1.05,.09],[sign*.46,.96,.17],.1,.085,.095)),
      part(an,trim,arm,box([sign*.455,1.03,.14],[.2,.035,.18])),
      part(ln,'#30282a',leg,limb(leg,[sign*.28,.39,.04],.15,.115,.15)),part(ln,'#5b4140',leg,box([sign*.26,.52,.17],[.19,.25,.06])),part(ln,trim,leg,box([sign*.28,.39,.15],[.23,.035,.035])),
      part(ln,fur,leg,limb([sign*.28,.39,.04],[sign*.3,.15,.05],.115,.1,.1)),
      part(ln,'#18191c',leg,box([sign*.3,.065,.12],[.24,.13,.35])));
    for(let i=0;i<5;i++)parts.push(part(ln,fur,leg,pyramid([[sign*.14,.78,-.13+i*.065],[sign*.35,.78,-.13+i*.065],[sign*.3,.82,-.09+i*.065]],[sign*.35,.59,-.1+i*.065])));
    for(let i=0;i<3;i++)parts.push(part(an,'#ded8bc',arm,pyramid([[sign*.46-.055+i*.045,.94,.25],[sign*.46-.025+i*.045,.94,.25],[sign*.46-.04+i*.045,.9,.25]],[sign*.46-.04+i*.045,.93,.43])));
    // Individual tapered tufts give the mantle a fur outline in actual 3D.
    for(let i=0;i<5;i++)parts.push(part(an,fur,arm,pyramid([[sign*(width-.05),1.39,-.15+i*.065],[sign*(width+.14),1.39,-.15+i*.065],[sign*(width+.1),1.45,-.11+i*.065]],[sign*(width+.15),1.2,-.12+i*.065])));
  }
  if(female)parts.push(part('head','#14151c',head,loft([{x:0,y:1.75,z:-.02,w:.19,d:.16},{x:0,y:1.87,z:-.04,w:.13,d:.13}]),loft([{x:0,y:1.8,z:-.17,w:.09,d:.09},{x:.04,y:1.52,z:-.23,w:.12,d:.13},{x:.08,y:1.25,z:-.22,w:.06,d:.07}])));
  else parts.push(part('head','#211b1c',head,loft([{x:0,y:1.78,z:-.03,w:.055,d:.14},{x:0,y:1.91,z:-.04,w:.025,d:.1}])));
  return parts;
}

/** Farsalam Waqas: gray rat, red wrapped turban and sleeveless sash from the reference. */
export function createRatWarriorParts():MeshPart[]{
 const skin='#686e72',red='#a73b29',gold='#b69858',head:Vec3=[0,1.53,.01],torso:Vec3=[0,1.03,0],parts:MeshPart[]=[];
 parts.push(part('torso',red,torso,loft([{x:0,y:.8,z:0,w:.21,d:.14},{x:0,y:1.2,z:0,w:.23,d:.15},{x:0,y:1.4,z:0,w:.27,d:.15}])),part('torso','#c55034',torso,prism([[-.23,1.41],[-.08,1.44],[.2,.97],[.1,.92]],.16,.18)),part('torso','#322c27',torso,box([0,.89,0],[.47,.11,.33])),part('torso',gold,torso,box([0,.89,.18],[.13,.075,.025])),part('torso',red,torso,prism([[-.11,.92],[.16,.87],[.24,.54],[-.07,.56]],.12,.19)),part('torso','#817868',torso,loft([{x:0,y:.59,z:0,w:.23,d:.15},{x:0,y:.75,z:0,w:.2,d:.14}])));
 parts.push(part('head',skin,head,loft([{x:0,y:1.45,z:0,w:.12,d:.12},{x:0,y:1.64,z:.025,w:.18,d:.15},{x:0,y:1.76,z:-.015,w:.14,d:.12}])),part('head','#85898a',head,loft([{x:0,y:1.45,z:.18,w:.08,d:.08},{x:0,y:1.54,z:.28,w:.11,d:.14},{x:0,y:1.6,z:.21,w:.09,d:.1}])),part('head','#ba9182',head,box([0,1.54,.425],[.105,.055,.045])),part('head','#332e2b',head,box([0,1.46,.33],[.15,.025,.08])),part('head','#dfd9b8',head,box([-.02,1.46,.377],[.03,.043,.025]),box([.02,1.46,.377],[.03,.043,.025])));
 for(const sign of[-1,1]){parts.push(part('head',skin,head,loft([{x:sign*.2,y:1.65,z:-.025,w:.09,d:.045},{x:sign*.23,y:1.86,z:-.025,w:.095,d:.045},{x:sign*.2,y:1.94,z:-.025,w:.045,d:.025}])),part('head','#ad8985',head,box([sign*.23,1.8,.025],[.11,.17,.022])),part('head','#e9dfba',head,box([sign*.114,1.65,.164],[.066,.074,.025])),part('head','#262b2c',head,box([sign*.115,1.65,.181],[.026,.055,.015])),part('head','#303437',head,box([sign*.105,1.705,.172],[.1,.02,.022])));const arm:Vec3=[sign*.27,1.37,0],leg:Vec3=[sign*.14,.72,0],an=sign<0?'leftArm':'rightArm',ln=sign<0?'leftLeg':'rightLeg';parts.push(part(an,skin,arm,limb(arm,[sign*.35,1.12,.03],.092,.07,.085),limb([sign*.35,1.12,.03],[sign*.4,.96,.18],.07,.05,.07)),part(an,'#b19a8d',arm,box([sign*.4,.95,.2],[.105,.12,.12])),part(an,'#d5c9a6',arm,limb([sign*.32,1.25,.02],[sign*.34,1.2,.025],.095,.09,.09)),part(ln,'#827d6d',leg,limb(leg,[sign*.16,.3,0],.13,.085,.115)),part(ln,skin,leg,limb([sign*.16,.3,0],[sign*.17,.1,.08],.085,.065,.08)),part(ln,'#b1a090',leg,box([sign*.17,.065,.17],[.18,.11,.3])));}
 for(let i=0;i<5;i++)parts.push(part('head',i%2?'#bc452d':red,head,loft([{x:0,y:1.75+i*.045,z:-.015,w:.19-i*.011,d:.175-i*.008},{x:0,y:1.81+i*.045,z:-.025,w:.175-i*.011,d:.16-i*.008}])));
 const tail:Vec3=[0,.72,-.16];let last:Vec3=[0,.72,-.16];for(let i=1;i<=12;i++){const t=i/12,p:Vec3=[-.35*Math.sin(t*Math.PI),.7-.42*Math.sin(t*Math.PI)+.7*t*t,-.16-t*1.45];parts.push(part('tail',i%2?'#ac8c81':'#94796f',tail,limb(last,p,.055*(1-t*.7),.052*(1-t*.7),.06,5)));last=p;}
 const hand:Vec3=[.4,.95,.2];parts.push(part('sword',gold,hand,box([.4,.99,.26],[.11,.09,.3]),box([.4,.94,.17],[.08,.08,.23])),part('sword','#bec9cd',hand,prism([[.34,1.03],[.47,1.03],[.45,3.12],[.36,3.36],[.32,3.1]],.25,.3)),part('sword','#e1e5df',hand,prism([[.36,1.04],[.4,1.04],[.36,3.36],[.32,3.1]],.302,.312)));
 return parts;
}

/** Arraf's white hood, long rat muzzle and tail, with green bottles and gold caster bands. */
export function createArrafParts():MeshPart[]{
 const white='#d3e4e7',shadow='#95adb7',green='#236b54',gold='#c7a85b',head:Vec3=[0,1.53,.01],torso:Vec3=[0,1.03,0];
 const parts=createRatWarriorParts().filter(p=>p.name!=='sword'&&!(p.name==='head'&&(p.color==='#a73b29'||p.color==='#bc452d'))).map(p=>({...p,color:p.color==='#686e72'||p.color==='#85898a'?'#c4cfd2':p.color==='#a73b29'||p.color==='#c55034'?white:p.color==='#827d6d'||p.color==='#817868'?shadow:p.color==='#322c27'?green:p.color==='#d5c9a6'?gold:p.color}));
 parts.push(part('cape',white,[0,1.37,-.1],loft([{x:0,y:.58,z:-.16,w:.28,d:.1},{x:0,y:1.18,z:-.15,w:.26,d:.1},{x:0,y:1.44,z:-.06,w:.29,d:.13}])),part('head',shadow,head,loft([{x:0,y:1.73,z:-.06,w:.19,d:.14},{x:0,y:1.9,z:-.09,w:.13,d:.1},{x:0,y:1.97,z:-.1,w:.045,d:.04}])),part('head',white,head,prism([[-.19,1.81],[-.12,1.82],[-.12,1.57],[-.04,1.4],[-.18,1.42],[-.23,1.63]],.08,.13),prism([[.19,1.81],[.12,1.82],[.12,1.57],[.04,1.4],[.18,1.42],[.23,1.63]],.08,.13)),part('torso',white,torso,prism([[-.12,1.49],[.12,1.49],[.2,1.17],[-.02,1.03],[-.17,1.22]],.18,.205)),part('torso',gold,torso,box([.1,1.18,.22],[.08,.04,.02])));
 for(const sign of[-1,1]){const arm:Vec3=[sign*.27,1.37,0];parts.push(part(sign<0?'leftArm':'rightArm',green,arm,limb(arm,[sign*.35,1.16,.025],.103,.082,.095)),part(sign<0?'leftArm':'rightArm',gold,arm,limb([sign*.38,1.04,.13],[sign*.39,1.0,.15],.081,.078,.08)),part('torso',green,torso,box([sign*.2,.94,.16],[.12,.18,.09])),part('torso',gold,torso,box([sign*.2,1.04,.16],[.06,.035,.065])));}
 const hand:Vec3=[.4,.95,.2];parts.push(part('cane','#76604d',hand,limb([.4,.18,.23],[.4,1.18,.23],.035,.035,.04,6)));for(let i=0;i<8;i++){const a=i*Math.PI/8,b=(i+1)*Math.PI/8;parts.push(part('cane',gold,hand,limb([.4+.14*Math.cos(a),1.18+.14*Math.sin(a),.23],[.4+.14*Math.cos(b),1.18+.14*Math.sin(b),.23],.035,.035,.04,5)));}return parts;
}

/** Macabre Danseur: high collar, red-edged black cape, formal shirt and cane-sword. */
export function createDanseurParts():MeshPart[]{
 const black='#18191f',red='#a52d42',white='#e9e3d7',skin='#c6987c',hair='#392b2b',torso:Vec3=[0,1.02,0],head:Vec3=[0,1.52,0],parts:MeshPart[]=[];
 parts.push(part('torso',black,torso,loft([{x:0,y:.77,z:0,w:.21,d:.14},{x:0,y:1.0,z:0,w:.2,d:.14}])),part('torso',white,torso,loft([{x:0,y:1.0,z:0,w:.2,d:.14},{x:0,y:1.35,z:0,w:.28,d:.16},{x:0,y:1.46,z:0,w:.23,d:.13}])),part('torso',black,torso,prism([[-.12,1.42],[-.015,1.39],[-.12,1.36]],.17,.2),prism([[.12,1.42],[.015,1.39],[.12,1.36]],.17,.2),box([0,1.39,.2],[.045,.055,.025])));
 for(const sign of[-1,1]){parts.push(part('torso',white,torso,prism([[sign*.07,1.5],[sign*.15,1.51],[sign*.16,1.44],[sign*.04,1.44]],.06,.155)));const arm:Vec3=[sign*.28,1.37,0],name=sign<0?'leftArm':'rightArm';parts.push(part(name,white,arm,limb(arm,[sign*.36,1.1,.035],.085,.067,.08),limb([sign*.36,1.1,.035],[sign*.42,.95,.16],.066,.055,.067)),part(name,skin,arm,box([sign*.42,.94,.16],[.10,.13,.10])));const leg:Vec3=[sign*.13,.84,0];parts.push(part(sign<0?'leftLeg':'rightLeg',black,leg,limb(leg,[sign*.15,.4,0],.1,.075,.10),limb([sign*.15,.4,0],[sign*.15,.10,.01],.074,.064,.08),box([sign*.15,.08,.10],[.17,.14,.29])));}
 parts.push(part('head',skin,head,loft([{x:0,y:1.49,z:.04,w:.105,d:.10},{x:0,y:1.65,z:0,w:.14,d:.12},{x:0,y:1.78,z:-.015,w:.12,d:.10}]),prism([[-.03,1.66],[.03,1.66],[.022,1.60],[-.022,1.60]],.12,.20)),part('head',hair,head,loft([{x:0,y:1.76,z:-.03,w:.16,d:.14},{x:0,y:1.86,z:-.07,w:.15,d:.13},{x:0,y:1.9,z:-.075,w:.075,d:.09}]),loft([{x:0,y:1.38,z:.035,w:.05,d:.075},{x:0,y:1.48,z:.06,w:.115,d:.12},{x:0,y:1.57,z:.06,w:.12,d:.10}]),box([0,1.58,.155],[.15,.045,.04])));
 for(const sign of[-1,1]){parts.push(part('head',hair,head,loft([{x:sign*.13,y:1.5,z:-.07,w:.055,d:.08},{x:sign*.15,y:1.72,z:-.07,w:.06,d:.12},{x:sign*.1,y:1.82,z:-.03,w:.07,d:.10}])));const outline=[[-.057,-.017],[-.037,-.034],[.035,-.034],[.056,-.017],[.054,.018],[.031,.032],[-.035,.032],[-.055,.015]];parts.push(part('head','#575961',head,prism(outline.map(([x,y])=>[x+sign*.068,y+1.635]),.175,.19)),part('head','#aeb2b6',head,box([sign*.065,1.65,.194],[.05,.007,.003])));}
 parts.push(part('head','#5b5654',head,box([0,1.636,.18],[.035,.015,.025])));
 const capePivot:Vec3=[0,1.45,-.10],rings=[{x:0,y:.28,z:-.26,w:.39,d:.035},{x:0,y:1.22,z:-.19,w:.34,d:.04},{x:0,y:1.48,z:-.10,w:.30,d:.05}];parts.push(part('cape',red,capePivot,loft(rings)),part('cape',black,capePivot,loft(rings.map(r=>({...r,w:r.w-.035,y:r.y+.025,d:r.d+.012})))));
 for(const sign of[-1,1])parts.push(part('torso',red,torso,prism([[sign*.21,1.40],[sign*.34,1.7],[sign*.19,1.65]],-.17,-.045)),part('torso',black,torso,prism([[sign*.22,1.42],[sign*.32,1.66],[sign*.2,1.63]],-.19,-.075)));
 const hand:Vec3=[.42,.95,.16];parts.push(part('cane',black,hand,limb([.42,.06,.16],[.42,1.03,.16],.031,.032,.034,8)),part('cane','#aa9671',hand,box([.42,1.03,.16],[.11,.055,.07])),part('swordtip','#bfc4ce',hand,limb([.42,.0,.16],[.42,.92,.16],.004,.029,.012,4)),part('sheath',black,[-.42,.95,.16],limb([-.42,.08,.16],[-.42,.96,.16],.031,.031,.034,8)));
 return parts;
}

