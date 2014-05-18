module Pod
  module TrunkApp
    class AssetsController < AppController

      get '/app.css' do
        send_file File.join(settings.public_folder, 'app.css')
      end
      
      get '/app.js' do
        send_file File.join(settings.public_folder, 'app.js')
      end

      get '/manage.css' do
        send_file File.join(settings.public_folder, 'manage.css')
      end

    end
  end
end