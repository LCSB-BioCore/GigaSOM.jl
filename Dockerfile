FROM julia

RUN julia -e 'import Pkg; Pkg.add("GigaSOM"); Pkg.resolve(); Pkg.status(); Pkg.instantiate(); Pkg.precompile()'

CMD ["julia"]
