require 'curb'
require 'nokogiri'
require 'csv'

category_url = ARGV[0]
filename = ARGV[1]
user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.95 Safari/537.36"
all_links = "//div[@id='ctl00_ctl00__nestedContent__mainpageContent__productFamilyListingView__listingUpdatePanel']//ul//li//a"
title_path = "//div[@id='ctl00_ctl00__nestedContent__mainpageContent_ProductFamilyDetailsView1__detailCnt']//h2"
img_src = "//img[@id='ctl00_ctl00__nestedContent__mainpageContent_ProductFamilyDetailsView1__productFamilyImagesView__mainImage']"
item_code_path = "//span[@id='ctl00_ctl00__nestedContent__mainpageContent_ProductFamilyDetailsView1__itemCode']"
price_path = "//span[@id='ctl00_ctl00__nestedContent__mainpageContent_ProductFamilyDetailsView1__hasPriceItemView__priceValueLabel']"
select_path = "//select[@name='ctl00$ctl00$_nestedContent$_mainpageContent$ProductFamilyDetailsView1$_productFamilySelectorsView$ddlSelector1']"

http = Curl.post(category_url, {:__EVENTTARGET => "ctl00$ctl00$_nestedContent$_pagingPlaceHolder$_pagingTop1Type2$_showAll"}
) do |http|
  http.headers['User-Agent'] = user_agent
end
html = Nokogiri::HTML(http.body_str)
array_urls = []
html.xpath(all_links).each do |anchor|
  array_urls.push(anchor['href'])
end

CSV.open("#{filename}.csv", "wb") do |csv|
  array_urls.each { |url|
    http = Curl.get(url) do |http|
      http.headers['User-Agent'] = user_agent
    end
    html = Nokogiri::HTML(http.body_str)
    title = html.xpath(title_path).text.strip
    item_code = html.xpath(item_code_path).text.split(': ').last.to_i
    img = html.xpath(img_src).attr('src')
    price = html.xpath(price_path).text.strip
    if html.at_xpath(select_path)
      state = html.xpath("//input[@id='__VIEWSTATE']").attr('value')
      variation = html.xpath(select_path+"//option[@selected='selected']").text.split('A ').last
      options = html.xpath(select_path+"//option[not(@selected='selected')]")
      options.each { |option|
        http = Curl::Easy.new(url)
        http.follow_location = true
        http.enable_cookies = true
        http.http_post(Curl::PostField.content('aspnetForm[__VIEWSTATE]', state),
                       Curl::PostField.content('aspnetForm[ctl00$ctl00$_nestedContent$_mainpageContent$ProductFamilyDetailsView1$_productFamilySelectorsView$ddlSelector1]', option.text))
        html = Nokogiri::HTML(http.body_str)
        price = html.xpath(price_path).text
        img = html.xpath(img_src).attr('src')
        csv << [title+" / #{variation}: #{option.text}", price, img, item_code]
        state = Nokogiri::HTML(http.body_str).xpath("//input[@id='__VIEWSTATE']").attr('value')
      }
    else
      csv << [title, price, img, item_code]
    end
  }
end