import { writeFileSync, mkdirSync } from 'node:fs';
import { createSpiderParts, createOctopusParts, createDogParts, createBatParts, createDryadParts, createMonkParts } from './actor-models.ts';
const models = {spider:createSpiderParts(),octopus:createOctopusParts(),plant_hound:createDogParts('plant'),slime_hound:createDogParts('slime'),bat:createBatParts(),dryad:createDryadParts(),researcher:createMonkParts().filter(part=>part.name!=='staff')};
const destination = new URL('../../assets/models/',import.meta.url);
mkdirSync(destination,{recursive:true});
for(const [name,parts] of Object.entries(models))writeFileSync(new URL(`${name}.json`,destination),JSON.stringify({source:'eyehaveewe-cyber/Zendelves',commit:'357aa0f77b0c8080074745e3f56b2a7a78241d04',path:'lib/xen/actor-models.ts',forward:'+Z',up:'+Y',parts}));
