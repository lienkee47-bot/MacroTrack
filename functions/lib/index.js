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
const params_1 = require("firebase-functions/params");
const node_fetch_1 = __importDefault(require("node-fetch"));
const crypto = __importStar(require("crypto"));
const fatSecretKey = (0, params_1.defineSecret)("FATSECRET_CONSUMER_KEY");
const fatSecretSecret = (0, params_1.defineSecret)("FATSECRET_CONSUMER_SECRET");
const API_URL = "https://platform.fatsecret.com/rest/server.api";
function percentEncode(str) {
    return encodeURIComponent(str).replace(/[!'()*~]/g, (c) => "%" + c.charCodeAt(0).toString(16).toUpperCase());
}
async function callFatSecret(params, secret) {
    const oauthParams = Object.assign(Object.assign({}, params), { oauth_consumer_key: fatSecretKey.value(), oauth_nonce: crypto.randomBytes(16).toString("hex"), oauth_signature_method: "HMAC-SHA1", oauth_timestamp: Math.floor(Date.now() / 1000).toString(), oauth_version: "1.0", format: "json" });
    const sortedKeys = Object.keys(oauthParams).sort();
    const baseParams = sortedKeys.map(k => `${percentEncode(k)}=${percentEncode(oauthParams[k])}`).join('&');
    const baseString = `POST&${percentEncode(API_URL)}&${percentEncode(baseParams)}`;
    const signingKey = `${percentEncode(secret)}&`;
    const signature = crypto.createHmac("sha1", signingKey).update(baseString).digest("base64");
    const body = baseParams + `&oauth_signature=${percentEncode(signature)}`;
    const res = await (0, node_fetch_1.default)(API_URL, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: body,
    });
    return await res.json();
}
exports.fetchFoodByBarcode = functions
    .runWith({ secrets: ["FATSECRET_CONSUMER_KEY", "FATSECRET_CONSUMER_SECRET"] })
    .https.onCall(async (data) => {
    var _a, _b;
    // --- UNIVERSAL ERROR SHIELD ---
    // This try-catch ensures the user never sees technical logs.
    try {
        const barcode = data === null || data === void 0 ? void 0 : data.barcode;
        if (!barcode)
            throw new Error("Missing barcode");
        const gtin = barcode.padStart(13, "0");
        const secret = fatSecretSecret.value();
        // STEP 1: Find the food_id
        const searchJson = await callFatSecret({
            method: "food.find_id_for_barcode",
            barcode: gtin
        }, secret);
        const foodId = (_a = searchJson === null || searchJson === void 0 ? void 0 : searchJson.food_id) === null || _a === void 0 ? void 0 : _a.value;
        if (!foodId || foodId === "0" || searchJson.error) {
            throw new Error("API_NOT_FOUND");
        }
        // STEP 2: Get full nutrition details
        const detailJson = await callFatSecret({
            method: "food.get.v4", // v4 includes better metric data
            food_id: foodId
        }, secret);
        const food = detailJson === null || detailJson === void 0 ? void 0 : detailJson.food;
        if (!food || detailJson.error) {
            throw new Error("API_NOT_FOUND");
        }
        // Handle the "single serving vs array" quirk in FatSecret
        const servingsList = (_b = food.servings) === null || _b === void 0 ? void 0 : _b.serving;
        const s = Array.isArray(servingsList) ? servingsList[0] : servingsList;
        if (!s)
            throw new Error("NO_SERVING_DATA");
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
    }
    catch (err) {
        // LOG THE ACTUAL ERROR FOR YOU (The Developer)
        functions.logger.error("Internal Function Error:", err);
        // THROW THE CLEAN ERROR FOR THE USER
        throw new functions.https.HttpsError("not-found", "Product not found. Please use other methods.");
    }
});
//# sourceMappingURL=index.js.map