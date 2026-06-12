#!/usr/bin/env node

import { readFile } from "node:fs/promises";

const file = process.argv[2];

if (!file) {
  console.error("Usage: node validate-deck.mjs <deck.aislide>");
  process.exit(2);
}

const deck = JSON.parse(await readFile(file, "utf8"));
const errors = [];

function isNumber(value) {
  return typeof value === "number" && Number.isFinite(value);
}

function check(condition, message) {
  if (!condition) errors.push(message);
}

check(deck && typeof deck === "object", "Deck must be an object.");
check(deck.version === 1, "Deck version must be 1.");
if (deck.irVersion !== undefined) check(typeof deck.irVersion === "string", "Deck irVersion must be a string.");
if (deck.sourceKind !== undefined) check(typeof deck.sourceKind === "string", "Deck sourceKind must be a string.");
check(deck.canvas && typeof deck.canvas === "object", "Deck canvas is required.");
check(Array.isArray(deck.slides) && deck.slides.length > 0, "Deck needs at least one slide.");

if (deck.canvas) {
  check(isNumber(deck.canvas.width) && deck.canvas.width >= 320, "Canvas width must be >= 320.");
  check(isNumber(deck.canvas.height) && deck.canvas.height >= 180, "Canvas height must be >= 180.");
  check(typeof deck.canvas.background === "string", "Canvas background must be a string.");
}

const ids = new Set();

for (const [slideIndex, slide] of (deck.slides || []).entries()) {
  check(typeof slide.id === "string" && slide.id.length > 0, `Slide ${slideIndex + 1} needs an id.`);
  check(typeof slide.title === "string", `Slide ${slide.id || slideIndex + 1} needs a title.`);
  check(Array.isArray(slide.elements), `Slide ${slide.id || slideIndex + 1} elements must be an array.`);

  for (const element of slide.elements || []) {
    const prefix = `Slide ${slide.id || slideIndex + 1}, element ${element.id || "(missing id)"}`;
    check(typeof element.id === "string" && element.id.length > 0, `${prefix}: id is required.`);
    check(!ids.has(element.id), `${prefix}: id must be unique across the deck.`);
    ids.add(element.id);
    check(["text", "rect", "image", "line", "ellipse"].includes(element.type), `${prefix}: unsupported type.`);

    for (const key of ["x", "y", "w", "h", "rotation", "z"]) {
      check(isNumber(element[key]), `${prefix}: ${key} must be a finite number.`);
    }

    check(element.w > 0 && element.h > 0, `${prefix}: width and height must be positive.`);

    if (element.type === "text") {
      check(typeof element.text === "string", `${prefix}: text elements need text.`);
      check(element.style && isNumber(element.style.fontSize), `${prefix}: text elements need style.fontSize.`);
    }

    if (element.type === "image") {
      check(
        typeof element.imageSource === "string" || typeof element.src === "string",
        `${prefix}: image elements need imageSource or src.`
      );
    }

    for (const key of ["tagName", "htmlPath", "semanticRole", "semanticLabel", "groupId", "groupRole", "groupLabel", "sourceKind", "editability", "fidelity", "captureNote", "layoutMode", "imageSource", "imageAlt"]) {
      if (element[key] !== undefined) check(typeof element[key] === "string", `${prefix}: ${key} must be a string.`);
    }

    if (element.frame !== undefined) {
      check(element.frame && typeof element.frame === "object", `${prefix}: frame must be an object.`);
      for (const key of ["x", "y", "w", "h"]) {
        check(isNumber(element.frame?.[key]), `${prefix}: frame.${key} must be a finite number.`);
      }
    }
  }
}

if (errors.length) {
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`OK: ${deck.slides.length} slide(s), ${ids.size} element(s).`);
