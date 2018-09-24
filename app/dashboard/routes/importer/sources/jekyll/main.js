var fs = require("fs-extra");
var async = require("async");
var determinePath = require('./determinePath');
var extractDate = require('./extractDate');
var extractContent = require('./extractContent');
var extractMetadata = require('./extractMetadata');
var downloadImages = require('./downloadImages');
var handleIncludes = require('./handleIncludes');

if (require.main === module) {
  main(process.argv[2], process.argv[3], function(err) {
    if (err) throw err;
    console.log("Built!");
    process.exit();
  });
}

function main(sourceDirectory, outputDirectory, callback) {
  console.log("Extracting posts from", sourceDirectory, "to", outputDirectory);
  fs.emptyDirSync(outputDirectory);

  var names = fs.readdirSync(sourceDirectory + "/_posts");

  async.eachSeries(names, function(name, next) {

    // System file
    if (name[0] == ".") return next();

    function loadFile(callback) {
      var path = sourceDirectory + "/_posts/" + name;

      fs.readFile(path, "utf8", function(err, source) {
        var result = {
          name: name,
          outputDirectory: outputDirectory,
          source: source
        };
        callback(err, result);
      });
    }

    var tasks = [
      loadFile,
      extractContent,
      extractDate,
      determinePath,
      extractMetadata,
      downloadImages,
      handleIncludes
    ];

    async.waterfall(tasks, function(err, result) {

      var output = [];

      if (!result) {
        console.log('No result for ', name);
        return next();
      }

      if (result.metadata) {

        for (var i in result.metadata) {
          output.push(i + ': ' + result.metadata[i]);
        }

        output.push('');
      }

      output.push('#' + result.title);
      output.push('');

      output.push(result.content);

      output = output.join('\n');

      // date = result[0];
      // metadata = result[1];

      // result = metadataString.join("\n") + "\n\n" + result;

      // var content = sourceFile.split("---")[2];

      // result += "\n" + content.trim();
      // console.log(output);

      // console.log(
      //   "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  Input >"
      // );
      // console.log(result.source);
      // console.log(
      //   "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Output >"
      // );
      // console.log(output);
      // console.log("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
      // console.log(result.date.format("YYYY-MM-DD"), name);
      next();
    });
  });
}

module.exports = main;
