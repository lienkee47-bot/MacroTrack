"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.fetchFoodByBarcode = void 0;
const functions = __importStar(require("firebase-functions"));
const params_1 = require("firebase-functions/params"); // New 2026 way
const node_fetch_1 = __importDefault(require("node-fetch"));
const crypto = __importStar(require("crypto"));
// 1. Define the secrets at the top level
const fatSecretKey = (0, params_1.defineSecret)("FATSECRET_CONSUMER_KEY");
const fatSecretSecret = (0, params_1.defineSecret)("FATSECRET_CONSUMER_SECRET");
const API_URL = "https://platform.fatsecret.com/rest/server.api";
function percentEncode(str) {
    return encodeURIComponent(str).replace(/[!'()*~]/g, (c) => "%" + c.charCodeAt(0).toString(16).toUpperCase());
}
function generateOAuthSignature(params, consumerSecret) {
    const sortedKeys = Object.keys(params).sort();
    const sortedParams = sortedKeys.map(k => `${percentEncode(k)}=${percentEncode(params[k])}`).join('&');
    const signatureBaseString = `POST&${percentEncode(API_URL)}&${percentEncode(sortedParams)}`;
    const signingKey = `${percentEncode(consumerSecret)}&`;
    return crypto.createHmac("sha1", signingKey).update(signatureBaseString).digest("base64");
}
// 2. Attach the secrets to the function
exports.fetchFoodByBarcode = functions
    .runWith({ secrets: ["FATSECRET_CONSUMER_KEY", "FATSECRET_CONSUMER_SECRET"] })
    .https.onCall(async (data) => {
    var _a, _b;
    const barcode = data === null || data === void 0 ? void 0 : data.barcode;
    if (!barcode)
        throw new functions.https.HttpsError("invalid-argument", "No barcode provided.");
    const gtin = barcode.padStart(13, "0");
    // 3. Access the values directly
    const consumerKey = fatSecretKey.value();
    const consumerSecret = fatSecretSecret.value();
    const params = {
        method: "food.find_id_for_barcode.v2",
        oauth_consumer_key: consumerKey,
        oauth_nonce: crypto.randomBytes(16).toString("hex"),
        oauth_signature_method: "HMAC-SHA1",
        oauth_timestamp: Math.floor(Date.now() / 1000).toString(),
        oauth_version: "1.0",
        barcode: gtin,
        region: "MY",
        format: "json",
    };
    params.oauth_signature = generateOAuthSignature(params, consumerSecret);
    const body = Object.keys(params).map(k => `${percentEncode(k)}=${percentEncode(params[k])}`).join('&');
    const res = await (0, node_fetch_1.default)(API_URL, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: body,
    });
    const rawText = await res.text();
    let json;
    try {
        json = JSON.parse(rawText);
    }
    catch (e) {
        throw new functions.https.HttpsError("internal", "API sent back something that wasn't JSON.");
    }
    if (json.error) {
        throw new functions.https.HttpsError("internal", `FatSecret Error: [${json.error.code}] ${json.error.message}`);
    }
    const food = json === null || json === void 0 ? void 0 : json.food;
    if (!food)
        throw new functions.https.HttpsError("not-found", "Product not found in MY database.");
    const s = Array.isArray((_a = food.servings) === null || _a === void 0 ? void 0 : _a.serving) ? food.servings.serving[0] : (_b = food.servings) === null || _b === void 0 ? void 0 : _b.serving;
    return {
        name: food.food_name,
        brand: food.brand_name || "Generic",
        kcal: parseFloat(s === null || s === void 0 ? void 0 : s.calories) || 0,
        protein: parseFloat(s === null || s === void 0 ? void 0 : s.protein) || 0,
        carbs: parseFloat(s === null || s === void 0 ? void 0 : s.carbohydrate) || 0,
        fat: parseFloat(s === null || s === void 0 ? void 0 : s.fat) || 0,
    };
});
//# sourceMappingURL=index.js.map