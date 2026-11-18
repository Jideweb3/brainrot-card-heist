// main.ts — the make.fun entrypoint for Brainrot Card Heist (Node 22,
// standard library only).
//
// The game itself is the Rojo project beside this file: its scripts live in
// src/, and `rojo build default.project.json --output game.rbxl` produces
// the place file. This program hands the finished entry in:
//
//   1. copies game.rbxl and PLAY.json into the output directory,
//   2. copies src/ and screenshots/ after them, skipping every file or
//      folder whose name starts with a dot (the grader rejects dotted
//      names anywhere in the output, so .gitkeep and friends stay behind),
//   3. writes dossier.json — the summary the AI judge reads — using the
//      vendored make.fun library, under the scorer's own size caps.
//
// Run it the way the grader does, with MAKEFUN_OUTPUT_DIR standing in for
// /output when testing locally:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

/** The caps the scorer enforces; the dossier is built to fit inside them. */
const DOSSIER_CAPS = {
  text_max_bytes: 65536,
  screenshots: { max: 4, max_bytes: 262144 },
  max_instances: 500000,
  scripts_max_source_bytes: 8388608,
  scripts_max_path_chars: 1048576,
} as const;

/** Files that must exist beside main.ts before anything is copied. */
const REQUIRED_FILES = ['game.rbxl', 'PLAY.json'] as const;

/** Directory trees copied wholesale (minus dotted names). */
const TREES = ['src', 'screenshots'] as const;

const entryDir = fileURLToPath(new URL('.', import.meta.url));
const outputDir = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

/** cpSync filter: true for everything except names starting with a dot. */
function isShippable(path: string): boolean {
  return !basename(path).startsWith('.');
}

function requireEntryFiles(): void {
  for (const name of REQUIRED_FILES) {
    if (!existsSync(join(entryDir, name))) {
      throw new Error(`Cannot hand in the entry: ${name} is missing beside main.ts.`);
    }
  }
}

function copyTree(name: string): number {
  const from = join(entryDir, name);
  const to = join(outputDir, name);
  mkdirSync(to, { recursive: true });
  if (!existsSync(from)) {
    return 0;
  }
  cpSync(from, to, { recursive: true, filter: isShippable });
  return readdirSync(to, { recursive: true }).length;
}

/** PLAY.json is filled in at publish time; warn (never fail) while it is not. */
function checkPlayLink(): void {
  try {
    const play = JSON.parse(readFileSync(join(entryDir, 'PLAY.json'), 'utf8')) as { place_id?: number };
    if (!play.place_id) {
      console.warn('Note: PLAY.json does not name a published place yet — the entry gate will refuse it until publishing fills it in.');
    }
  } catch {
    console.warn('Note: PLAY.json could not be parsed; the entry gate will check it.');
  }
}

function handIn(): void {
  requireEntryFiles();
  checkPlayLink();
  mkdirSync(outputDir, { recursive: true });

  for (const name of REQUIRED_FILES) {
    copyFileSync(join(entryDir, name), join(outputDir, name));
  }
  const copied: string[] = [];
  for (const name of TREES) {
    copied.push(`${name}: ${copyTree(name)} files`);
  }

  const dossier = buildDossier(outputDir, DOSSIER_CAPS);
  writeFileSync(join(outputDir, 'dossier.json'), dossier);

  console.log(`Brainrot Card Heist handed in to ${outputDir} (${copied.join(', ')}; dossier: ${dossier.length} bytes).`);
}

handIn();
