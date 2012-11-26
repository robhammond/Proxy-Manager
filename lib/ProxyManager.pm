package ProxyManager;
use Mojo::Base 'Mojolicious';
use MongoDB::Connection;

# This method will run once at server start
sub startup {
  my $self = shift;

  my $config = $self->plugin('Config');

  $self->secret('manager of proxies');

  $self->attr(db => sub { 
      MongoDB::Connection
          ->new(host => $config->{database_host})
          ->get_database($config->{database_name});
  });
  $self->helper('db' => sub { shift->app->db });

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('example#welcome');
  # adding new proxies
  $r->post('/')->to('example#add');
}

1;
