var extname = require("path").extname;

module.exports = function(result, callback) {

  // ->
  var nameWithoutExtensionAndDate = result.name
    .split("-")
    .slice(3)
    .join("-")
    .split(".")
    .slice(0, -1)
    .join(".");

  var extension = extname(result.name);

  result.assetDirectory = result.outputDirectory + '/' + result.date.format("/YYYY/MM/DD-") + nameWithoutExtensionAndDate;
  result.pathWithAssets = result.assetDirectory + "/post" + extension;
  result.pathWithoutAssets = result.assetDirectory + extension;

  callback(null, result);
};
