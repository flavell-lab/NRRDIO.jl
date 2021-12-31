#### write
function nrrd_header(type_pix::DataType, spacing::Tuple{Float64, Float64, Float64},
        sizes::Tuple{Int64, Int64, Int64})
    "NRRD0004
# Complete NRRD file format specification at:
# http://teem.sourceforge.net/nrrd/format.html
type: $(DICT_DTYPE_W[type_pix])
dimension: 3
space: left-posterior-superior
sizes: $(sizes[1]) $(sizes[2]) $(sizes[3])
space directions: ($(spacing[1]),0,0) (0,$(spacing[2]),0) (0,0,$(spacing[3]))
kinds: domain domain domain
endian: little
encoding: gzip
space origin: (0,0,0)"
end

function write_nrrd(path_nrrd::String, data::AbstractArray, spacing::Tuple{Float64, Float64, Float64})

    header_str = nrrd_header(eltype(data), spacing, size(data))
    write(path_nrrd, header_str * "\n\n")

    open(GzipCompressorStream, path_nrrd, "a") do stream
        write(stream, data)
    end
end

#### read
function read_header_str(path_nrrd::String)
    open(path_nrrd, "r") do f
        if String(read(f,4)) != "NRRD"
            error("the file is not nrrd")
        end
        skip(f,5)
        readuntil(f, "\n\n"), position(f)
    end
end

function nrrd_header(header_str::String)
    list_str = filter(x->length(x)>0 && strip(x)[1] != '#', split(header_str, '\n'))
    header_dict = OrderedDict{String,String}()

    for str = list_str
        k, v = strip.(split(str, ":"))
        header_dict[k] = v
    end

    header_dict
end

mutable struct NRRD
    path_nrrd::String
    header_dict::OrderedDict
    data_psotion::Int

    function NRRD(path_nrrd)
        header_str, pos = read_header_str(path_nrrd)
        header_dict = nrrd_header(header_str)
        new(path_nrrd, header_dict, pos)
    end
end

function read_img(nrrd::NRRD)
    dtype = DICT_DTYPE_R[nrrd.header_dict["type"]]
    sizes = parse.(Int, split(nrrd.header_dict["sizes"]))
    data = Array{dtype}(undef, sizes...)

    open(nrrd.path_nrrd, "r") do f
        seek(f, nrrd.data_psotion)
        read!(GzipDecompressorStream(f), data)
    end
end
