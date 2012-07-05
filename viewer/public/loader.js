onmessage = function(event) {
  
  var index = event.data;
  
  var xhr = new XMLHttpRequest();
  xhr.open("GET", "/" + index, false);
  xhr.send();
  
  if (xhr.status == 200)
    postMessage({ index: index, tile: JSON.parse(xhr.responseText) });
  
}
