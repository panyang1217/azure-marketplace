var gulp = require("gulp");
var jsonfile = require('jsonfile');
var _ = require('lodash');
var replace = require('gulp-replace');

jsonfile.spaces = 2;

var resourceTemplate = {
  content: require("../../src/datanodes/data-nodes-template.json"),
  suffix: "disk-resources"
};

var encryptedResourceTemplate = {
  content: require("../../src/datanodes/data-nodes-encrypted-template.json"),
  suffix: "disk-encrypted-resources"
};

var encryptedKekResourceTemplate = {
  content: require("../../src/datanodes/data-nodes-encrypted-kek-template.json"),
  suffix: "disk-encrypted-kek-resources"
};

var allowedValues = require('../allowedValues.json');

var nthDisk = function(deploymentResource) {
  return function(i) {
    var disks = deploymentResource.properties.parameters.dataDisks.value.disks[0];
    var d = _.cloneDeep(disks);
    d.lun = i;
    d.name = d.name.replace(/_INDEX_/, i + 1);
    d.vhd.uri = d.vhd.uri.replace(/_INDEX_/, i + 1);
    return d;
  }
}

var dataNodeWithDataDisk = function (template, size, done) {
  var t = _.cloneDeep(template.content);

  var deploymentResources = _(t.resources).filter(function(r) { return r.type == "Microsoft.Resources/deployments"}).value();

  deploymentResources.forEach(function(rr) {
    if (rr.properties.parameters.dataDisks) {
      var mapDisks = nthDisk(rr);
      var disks = _.range(size).map(mapDisks);
      rr.properties.parameters.dataDisks["value"].disks = disks;
    }
  });


  var resource = "../src/datanodes/data-nodes-" + size + template.suffix + ".json";
  jsonfile.writeFile(resource, t, { flag: 'w' },function (err) {
    done();
  });
};
var dataNodeWithoutDataDisk = function (template, size, done) {
  var t = _.cloneDeep(template.content);
  t.resources = _(t.resources).filter(r=>r.type != "Microsoft.Storage/storageAccounts").value();
  var deploymentResources = _(t.resources).filter(function(r) { return r.type == "Microsoft.Resources/deployments"}).value();

  deploymentResources.forEach(function(rr) {
    rr.properties.parameters.dataDisks = null;
    delete rr.properties.parameters.dataDisks;
    rr.dependsOn = [rr.dependsOn[0]];
  });

  delete t.variables.nodesPerStorageAccount;
  delete t.variables.storageAccountPrefix;
  delete t.variables.storageAccountPrefixCount;
  delete t.variables.newStorageAccountNamePrefix;

  var resource = "../src/datanodes/data-nodes-" + size + template.suffix + ".json";
  jsonfile.writeFile(resource, t, { flag: 'w' },function (err) {
    done();
  });
};

gulp.task("generate-data-nodes-resource", function(cb) {
  var cbCalled = 0;
  var templates = [resourceTemplate, encryptedResourceTemplate, encryptedKekResourceTemplate];
  var done =function() {
    cbCalled++;
    if (cbCalled == (allowedValues.dataDisks.length * templates.length) + templates.length)
      cb();
  };

  templates.forEach(function (template) {
    allowedValues.dataDisks.forEach(function (size) {
      dataNodeWithDataDisk(template, size, done);
    });
    dataNodeWithoutDataDisk(template, 0, done);
  });

});
