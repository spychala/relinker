require 'sinatra'
require 'pg'
require 'nokogiri'
require 'open-uri'
require "net/http"
require 'yaml'

configure { set :server, :puma }

ENV['RACK_ENV'] ||= 'development'
if ENV['RACK_ENV'] == 'development'
  require "sinatra/reloader"
  require 'byebug'
  configure :development do
    register Sinatra::Reloader
  end
  set :port, 8088
end

  #set :static, true
  #set :public_folder, "static"
  #set :views, "views"
  DBCONFIG ||= YAML.load_file("./config/database.yml")[ENV['RACK_ENV']]

  def check_if_forum(url)
    doc = Nokogiri::HTML(open(url)) rescue nil
    wynik = doc.xpath("//*")
    sprawdzenie = 0
    if wynik.to_s.downcase.include? "forum"
      sprawdzenie = 1
    end
    return sprawdzenie
  end # koniec funkcji check_if_forum

  def check_response(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(url)
    response = http.request(request)
    return response.code
  end

class Relinker < Sinatra::Base
  get '/' do
    erb :index
  end

get '/kontakt' do
    erb :kontakt
  end


# ---------------- sprawdzenie linki sponsorowane --------------------------- 

 get '/sprawdz-linki-sponsorowane' do
    adresy = params["adresy"]
    erb :indexsponsorowane
  end

# post sprawdzenie premium
  post '/sprawdz-linki-sponsorowane' do
      con = PG.connect(dbname: DBCONFIG["database"], user: DBCONFIG["username"], password: DBCONFIG["password"])
      potwierdzone_lh = []
      potwierdzone_wp = []
      potwierdzone_wspolne = []
      adresy = params[:adresy] || "brak"
      przeslane = adresy.split(/\r?\n/)
      przeslane.each do |link|
        link = link.gsub("https://","").gsub("http://","").gsub("www.","").gsub("/","")

        rs_lh = con.exec "select 1 from linkhouse where strona LIKE '%#{link}%';"
        rs_wp = con.exec "select 1 from whitepress where strona LIKE '%#{link}%';"
        if rs_wp.num_tuples > 0 and rs_lh.num_tuples > 0
          potwierdzone_wspolne.push(link)
        elsif rs_wp.num_tuples > 0
          potwierdzone_wp.push(link)
        elsif rs_lh.num_tuples > 0
          potwierdzone_lh.push(link)
        end

      end
      erb :wynikisponsorowane, :locals => {'adresy_wspolne' => potwierdzone_wspolne, 'adresy_wp' => potwierdzone_wp, 'adresy_lh' => potwierdzone_lh}
  end

# ---------------- sprawdzenie linki z forum ---------------------------  

  get '/sprawdz-linki-forum' do
    adresy = params["adresy"]
    erb :indexforum
  end

# --post sprawdzenie forum
  post '/sprawdz-linki-forum' do
      fora = []
      adresy = params[:adresy] || "brak"
      przeslane = adresy.split(/\r?\n/)
      przeslane.each do |link|
        link = link.gsub("https://","").gsub("http://","").gsub("www.","").gsub("/","")
        puts "......................."
        puts "sprawdzam #{link}"
        forum = check_if_forum("http://#{link}") rescue nil
        if forum == 1
          fora.push(link)
        end

      end
      erb :wynikiforum, :locals => {'fora' => fora}
  end
end
