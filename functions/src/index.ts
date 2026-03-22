import * as functions from "firebase-functions";
import fetch from "node-fetch";
import * as crypto from "crypto";

// ──────────────────────────────────────────────────────────────
// FatSecret OAuth 1.0 — Signed Requests
// ──────────────────────────────────────────────────────────────
// Store your credentials with:
//   firebase functions:config:set fatsecret.consumer_key="YOUR_KEY"
//   firebase functions:config:set fatsecret.consumer_secret="YOUR_SECRET"
// ──────────────────────────────────────────────────────────────

const API_URL = "https://platform.fatsecret.com/rest/server.api";

function percentEncode(str: string): string {
  return encodeURIComponent(str).replace(/[!'()*]/g, (c) => {
    return "%" + c.charCodeAt(0).toString(16).toUpperCase();
  });
}

function generateOAuthSignature(params: Record<string, string>, consumerSecret: string): string {
  const sortedKeys = Object.keys(params).sort();
  const sortedParams = sortedKeys.map(k => `${percentEncode(k)}=${percentEncode(params[k])}`).join('&');

  const httpMethod = "POST";
  const requestUrl = API_URL;

  const signatureBaseString = `${httpMethod}&${percentEncode(requestUrl)}&${percentEncode(sortedParams)}`;

  const signingKey = `${percentEncode(consumerSecret)}&`;
  const hmac = crypto.createHmac("sha1", signingKey);
  hmac.update(signatureBaseString);
  return hmac.digest("base64");
}

// ──────────────────────────────────────────────────────────────
// Callable Cloud Function: fetchFoodByBarcode
// ──────────────────────────────────────────────────────────────

export const fetchFoodByBarcode = functions.https.onCall(
  async (data: { barcode?: string }) => {
    const barcode = data?.barcode;
    if (!barcode || typeof barcode !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "A valid barcode string is required."
      );
    }

    // Pad to 13 digits (GTIN-13) as required by FatSecret
    const gtin = barcode.padStart(13, "0");

    const consumerKey = process.env.FATSECRET_KEY;
    const consumerSecret = process.env.FATSECRET_SECRET;

    if (!consumerKey || !consumerSecret) {
      throw new functions.https.HttpsError(
        "internal",
        "FatSecret credentials are missing from environment variables. Make sure .env is correctly set."
      );
    }

    const timestamp = Math.floor(Date.now() / 1000).toString();
    const nonce = crypto.randomBytes(16).toString("hex");

    const params: Record<string, string> = {
      method: "food.find_id_for_barcode.v2",
      oauth_consumer_key: consumerKey,
      oauth_nonce: nonce,
      oauth_signature_method: "HMAC-SHA1",
      oauth_timestamp: timestamp,
      oauth_version: "1.0",
      barcode: gtin,
      region: "MY",
      format: "json",
    };

    const signature = generateOAuthSignature(params, consumerSecret);
    params.oauth_signature = signature;

    const bodyParams = new URLSearchParams();
    for (const [key, value] of Object.entries(params)) {
      bodyParams.append(key, value);
    }

    const res = await fetch(API_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: bodyParams.toString(),
    });

    if (!res.ok) {
      throw new functions.https.HttpsError(
        "not-found",
        "Product not found. Please try other methods."
      );
    }

    const json = (await res.json()) as Record<string, any>;

    // API sometimes returns 200 OK but with an internal error object
    if (json.error) {
      functions.logger.error("FatSecret API Error:", json.error);
      throw new functions.https.HttpsError(
        "not-found",
        "Product not found. Please try other methods."
      );
    }

    const food = json?.food;

    if (!food) {
      throw new functions.https.HttpsError(
        "not-found",
        "Product not found. Please try other methods."
      );
    }

    // Extract the default serving (first in servings list)
    const servings = food.servings?.serving;
    const serving = Array.isArray(servings) ? servings[0] : servings;

    const name: string = food.food_name ?? "Unknown";
    const servingSize: number = parseFloat(
      serving?.metric_serving_amount ?? serving?.serving_description ?? "100"
    ) || 100;
    const servingUnit: string =
      serving?.metric_serving_unit ?? "g";
    const kcal: number = parseFloat(serving?.calories ?? "0") || 0;
    const protein: number = parseFloat(serving?.protein ?? "0") || 0;
    const carbs: number = parseFloat(serving?.carbohydrate ?? "0") || 0;
    const fat: number = parseFloat(serving?.fat ?? "0") || 0;

    return {
      name,
      servingSize,
      servingUnit,
      kcal,
      protein,
      carbs,
      fat,
    };
  }
);
