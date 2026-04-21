const functions = require("firebase-functions");

const { GoogleGenerativeAI } = require("@google/generative-ai");



exports.getPlantAdvice = functions.https.onRequest(async (req, res) => {
  try {
    const { soil, light } = req.body;

    const model = genAI.getGenerativeModel({
      model: "gemini-pro"
    });

    const prompt = `
You are a smart plant care assistant.

Soil moisture: ${soil} (higher = drier)
Light level: ${light} lux

Give short, helpful advice in 1-2 sentences.
`;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    res.json({ advice: text });
  } catch (error) {
    console.error(error);
    res.status(500).send("Error generating advice");
  }
});