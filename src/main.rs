//! A small application that lets people upload files

extern crate tera;

use actix_files::Files;
use actix_multipart::{Field, Multipart, MultipartError};
use actix_web::{
    error, middleware,
    web::{self, Path},
    App, Error, HttpRequest, HttpResponse, HttpServer, Responder, Result,
};
use futures::{
    future::{err, Either},
    {Future, Stream},
};
use rand::{
    distributions::Alphanumeric,
    {thread_rng, Rng},
};

use std::io::Write;
use std::{env, fs::File, iter, path::PathBuf};

/// Small utility function that generates random filenames and paths
fn get_filename() -> (String, String) {
    let mut rng = thread_rng();
    let file_name: String = iter::repeat(())
        .map(|()| rng.sample(Alphanumeric))
        .take(16)
        .collect::<String>()
        .as_str()
        .into();

    let mut path = PathBuf::new();
    path.push(
        env::var("SHELFIE_STORAGE").unwrap_or(
            env::current_dir()
                .expect("Failed to get current directory!")
                .to_str()
                .unwrap()
                .into(),
        ),
    );
    path.push(file_name.clone());
    (file_name, path.as_os_str().to_str().unwrap().to_owned())
}

/// Async IO file storage handler
pub fn save_file(field: Field) -> impl Future<Item = String, Error = Error> {
    let (name, path) = get_filename();

    let file = match File::create(path) {
        Ok(file) => file,
        Err(e) => return Either::A(err(error::ErrorInternalServerError(e))),
    };
    Either::B(
        field
            .fold((file, 0i64), move |(mut file, mut acc), bytes| {
                web::block(move || {
                    file.write_all(bytes.as_ref()).map_err(|e| {
                        println!("file.write_all failed: {:?}", e);
                        MultipartError::Payload(error::PayloadError::Io(e))
                    })?;
                    acc += bytes.len() as i64;
                    Ok((file, acc))
                })
                .map_err(|e: error::BlockingError<MultipartError>| match e {
                    error::BlockingError::Error(e) => e,
                    error::BlockingError::Canceled => MultipartError::Incomplete,
                })
            })
            .map(move |(_, _)| name)
            .map_err(|e| {
                println!("save_file failed, {:?}", e);
                error::ErrorInternalServerError(e)
            }),
    )
}

/// Handle multi-part stream forms
pub fn upload(multipart: Multipart) -> impl Future<Item = HttpResponse, Error = Error> {
    multipart
        .map_err(error::ErrorInternalServerError)
        .map(|field| save_file(field).into_stream())
        .flatten()
        .collect()
        .map(|vec| {
            let file = vec.get(0).unwrap();
            HttpResponse::SeeOther()
                .header("Location", format!("/id/{}", file))
                .finish()
        })
        .map_err(|e| {
            println!("failed: {}", e);
            e
        })
}

/// Display the main file upload dialog
fn index(tmpl: web::Data<tera::Tera>, _: HttpRequest) -> Result<impl Responder> {
    let ctx = tera::Context::new();

    Ok(HttpResponse::Ok().content_type("text/html").body(
        tmpl.render("home.html", &ctx)
            .map_err(|_| error::ErrorInternalServerError("Template error"))?,
    ))
}

/// Display an image ID
fn display(tmpl: web::Data<tera::Tera>, request: HttpRequest, id: Path<String>) -> Result<impl Responder> {
    let mut ctx = tera::Context::new();
    ctx.insert("id", &*id);
    ctx.insert("host", request.headers().get("host")
        .ok_or(error::ErrorBadRequest("Missing Host header"))?
        .to_str().map_err(|_| error::ErrorBadRequest("Invalid Host header"))?);

    Ok(HttpResponse::Ok().content_type("text/html").body(
        tmpl.render("show.html", &ctx)
            .map_err(|_| error::ErrorInternalServerError("Template error"))?,
    ))
}

/// Main application entry point
fn main() -> std::io::Result<()> {
    std::env::set_var("RUST_LOG", "actix_server=info,actix_web=info");
    env_logger::init();
    let port = env::var("SHELFIE_PORT")
        .map(|p| p.parse())
        .unwrap_or(Ok(9090))
        .unwrap();

    HttpServer::new(|| {
        let mut tera = tera::Tera::default();
        tera.add_raw_templates(vec![
          ("shelfie.css", include_str!("../templates/shelfie.css")),
          ("base.html", include_str!("../templates/base.html")),
          ("home.html", include_str!("../templates/home.html")),
          ("show.html", include_str!("../templates/show.html")),
        ]).unwrap();

        let data = env::var("SHELFIE_STORAGE").unwrap_or(
            env::current_dir()
                .expect("Failed to get current directory!")
                .to_str()
                .unwrap()
                .into(),
        );

        App::new()
            .data(tera)
            .wrap(middleware::Logger::default())
            .service(
                web::resource("/")
                    .route(web::get().to(index))
                    .route(web::post().to_async(upload)),
            )
            .service(web::resource("/id/{id}").route(web::get().to(display)))
            .service(Files::new("/static", "static"))
            .service(Files::new("/images", data))
    })
    .bind(format!("127.0.0.1:{}", port))?
    .run()
}
