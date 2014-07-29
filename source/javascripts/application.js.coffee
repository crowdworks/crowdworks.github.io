#= require_tree ./vendor
#= require_tree ./lib

#jQuery to collapse the navbar on scroll
$(window).scroll ->
  if $(".navbar").offset() and $(".navbar").offset().top > 50
    $(".navbar-fixed-top").addClass "top-nav-collapse"
  else
    $(".navbar-fixed-top").removeClass "top-nav-collapse"
  return


#jQuery for page scrolling feature - requires jQuery Easing plugin
$ ->
  $(".page-scroll a").bind "click", (event) ->
    $anchor = $(this)
    $("html, body").stop().animate
      scrollTop: $($anchor.attr("href")).offset().top
    , 500, "easeInOutExpo"
    event.preventDefault()
    return

  return
