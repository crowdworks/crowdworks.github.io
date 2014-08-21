$(function() {
  var w = $(window).width();
  var h = $(window).height();
  $(".article-cover").css("width",w).css("height",h * 0.5);
});

$(window).resize(function(){
  var w = $(window).width();
  var h = $(window).height();
  $(".article-cover").css("width",w).css("height",h * 0.5);
});