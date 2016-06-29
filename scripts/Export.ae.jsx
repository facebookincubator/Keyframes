﻿#target "aftereffects"#include "./lib/ExtendScript/index-ae.jsxinc"if (typeof STDOUT == 'undefined') {  STDOUT = $;}var console = {  log: function() {    var args = Array.prototype.slice.call(arguments, 0);     args.forEach(function(arg, index) {      if (index > 0) STDOUT.write(" ");      if (typeof arg != 'string') {        arg = JSON.stringify(arg, null, 2);      }      STDOUT.write('' + arg);    });    STDOUT.write("\n");  },  time: function(label) {    console.log(label + " starting...");    console.time['Timer ' + label] = Date.now();  },  timeEnd: function(label) {    var duration = Date.now() - console.time['Timer ' + label];    console.log(label + " Time: " + (duration / 1000));    delete console.time['Timer ' + label];  },};function inspect(thing){  return ''    + Object.prototype.toString.call(thing)    + '\n'    + Object.keys(thing).map(function(key)  {return typeof comp[key] + ': ' + key;}).sort().join('\n')  ;}////////////////////////////////////////////////////////////////////////////////app.onError = function(message, severity){  //$.writeln(severity, ": ", message);};////////////////////////////////////////////////////////////////////////////////fs_writeFileSync = function(path, data){  var file = new File(path);  file.open('w');  file.write(data);  file.close();  return file;}fs_readFileSync = function(path){  var file = new File(path);  file.open('r');  try {    var innards = file.read();  }  finally {    file.close();  }  return innards;}//////////////////////////////////////////////////////////////////////////////////fs_writeFileSync(app.project.file.fsName + '.json', JSON.stringify(app.project, null, 2));function main(){  combineAllTheIndivdualCompFilesIntoASingleExport(    app.project.file.fsName + '.json',    exportEachCompAndReturnTheirPaths()  );}function exportEachCompAndReturnTheirPaths(){  var comps = app.project.ao_comps();  return comps.filter(Boolean).map(function(comp){    console.log(comp.name);    var filePath = app.project.file.fsName + '.comp' + comp.name + '.json';    var file = new File(filePath);    if (file.exists && file.length > 0) {      console.log('    Skipping because this file already exists');      return filePath;    }    console.time('        JSON.stringify "'+ comp.name +'"');    var json = JSON.stringify(comp, function(key, value){      //console.log('            ' + key);      return value;    }, 2);    console.timeEnd('        JSON.stringify "'+ comp.name +'"');    console.time('        fs_writeFileSync("'+filePath+'")');    fs_writeFileSync(filePath, json);    console.timeEnd('        fs_writeFileSync("'+filePath+'")');    return filePath;  });}function combineAllTheIndivdualCompFilesIntoASingleExport(path, compFilePaths){  var lastIndex = compFilePaths.length - 1;  var file = new File(path);  file.open('w');  file.writeln('{"items":[');  compFilePaths.forEach(function(filePath, index){    file.writeln( fs_readFileSync(filePath) || JSON.stringify({ error:'Missing file "' + filePath + '"' }));    if (index !== lastIndex) {      file.writeln(',');    }  });  file.writeln("]}");  file.close();}////////////////////////////////////////////////////////////////////////////////VirtualTween.FPS = 120;VirtualTween.FRAME_TIME = 1 / VirtualTween.FPS;VirtualTween.EnableTweenValues = false;Object.ao_shallowClone.KeyWHITELIST = [  'activeItem', // $id  'displayStartTime',  'duration',  'enabled',  'file',  'frameRate',  'height',  'id',  'inPoint',  'index',  'isModified',  'isTimeVarying',  'keyframeTweens',  'layers',  'name',  'outPoint',  'parent', // $index  'properties',  'source', // $id  'startTime',  'threeDLayer',  'time',  'value',  'values',  'width',  'workAreaDuration',  'workAreaStart',];main();