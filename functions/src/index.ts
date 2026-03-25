import * as functions from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import fetch from "node-fetch";
import * as crypto from "crypto";

const fatSecretKey = defineSecret("FATSECRET_CONSUMER_KEY");
const fatSecretSecret = defineSecret("FATSECRET_CONSUMER_SECRET");
const API_URL = "https://platform.fatsecret.com/rest/server.api";

function percentEncode(str: string): string {
  return encodeURIComponent(str).replace(/[!'()*~]/g, (c) => "%" + c.charCodeAt(0).toString(16).toUpperCase());
}

async function callFatSecret(params: Record<string, string>, secret: string): Promise<any> {
  const oauthParams = {
    ...params,
    oauth_consumer_key: fatSecretKey.value(),
    oauth_nonce: crypto.randomBytes(16).toString("hex"),
    oauth_signature_method: "HMAC-SHA1",
    oauth_timestamp: Math.floor(Date.now() / 1000).toString(),
    oauth_version: "1.0",
    format: "json",
  };

  const sortedKeys = Object.keys(oauthParams).sort();
  const baseParams = sortedKeys.map(k => `${percentEncode(k)}=${percentEncode(oauthParams[k as keyof typeof oauthParams])}`).join('&');
  const baseString = `POST&${percentEncode(API_URL)}&${percentEncode(baseParams)}`;
  const signingKey = `${percentEncode(secret)}&`;
  const signature = crypto.createHmac("sha1", signingKey).update(baseString).digest("base64");

  const body = baseParams + `&oauth_signature=${percentEncode(signature)}`;

  const res = await fetch(API_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body,
  });

  return await res.json();
}

export const fetchFoodByBarcode = functions
  .runWith({ secrets: ["FATSECRET_CONSUMER_KEY", "FATSECRET_CONSUMER_SECRET"] })
  .https.onCall(async (data: { barcode?: string }) => {
    
    // --- UNIVERSAL ERROR SHIELD ---
    // This try-catch ensures the user never sees technical logs.
    try {
      const barcode = data?.barcode;
      if (!barcode) throw new Error("Missing barcode");
      
      const gtin = barcode.padStart(13, "0");
      const secret = fatSecretSecret.value();

      // STEP 1: Find the food_id
      const searchJson = await callFatSecret({
        method: "food.find_id_for_barcode",
        barcode: gtin
      }, secret);

      const foodId = searchJson?.food_id?.value;
      if (!foodId || foodId === "0" || searchJson.error) {
        throw new Error("API_NOT_FOUND");
      }

      // STEP 2: Get full nutrition details
      const detailJson = await callFatSecret({
        method: "food.get.v4", // v4 includes better metric data
        food_id: foodId
      }, secret);

      const food = detailJson?.food;
      if (!food || detailJson.error) {
        throw new Error("API_NOT_FOUND");
      }

      // Handle the "single serving vs array" quirk in FatSecret
      const servingsList = food.servings?.serving;
      const s = Array.isArray(servingsList) ? servingsList[0] : servingsList;

      if (!s) throw new Error("NO_SERVING_DATA");

      // Extract and format data
      return {
        name: food.food_name || "Unknown Product",
        brand: food.brand_name || "Generic",
        kcal: Math.round(parseFloat(s.calories || "0")),
        protein: parseFloat(s.protein || "0"),
        carbs: parseFloat(s.carbohydrate || "0"),
        fat: parseFloat(s.fat || "0"),
        // NEW: Serving size and unit extraction
        servingSize: parseFloat(s.metric_serving_amount || "1"),
        servingUnit: s.metric_serving_unit || s.serving_description || "unit",
      };

    } catch (err) {
      // LOG THE ACTUAL ERROR FOR YOU (The Developer)
      functions.logger.error("Internal Function Error:", err);

      // THROW THE CLEAN ERROR FOR THE USER
      throw new functions.https.HttpsError(
        "not-found",
        "Product not found. Please use other methods."
      );
    }
  });