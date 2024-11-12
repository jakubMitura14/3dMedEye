using ModernGL
using GLFW,HDF5
using GeometryTypes

# Vertex shader source code
const vertex_shader_code = """ 
#version 460
  layout (location = 0) in vec3 aPos;
  layout (location = 1) in vec3 aColor;
  layout (location = 2) in vec2 aTexCoord;
  out vec3 ourColor;
  smooth out vec2 TexCoord0;
  void main()
  {
      gl_Position = vec4(aPos, 1.0);
      ourColor = aColor;
   //  TexCoord0 = vec2(-aTexCoord.y, aTexCoord.x);
     TexCoord0 = aTexCoord;

  }
    """

# Fragment shader source code
const fragment_shader_source = """ 

    #version 460


    out vec4 FragColor;
    in vec3 ourColor;
    smooth in vec2 TexCoord0;


    uniform sampler2D CTIm; // mask image sampler
    uniform vec4 CTImColorMask= vec4(1.0,1.0,1.0,1.0); //controlling colors
    uniform int CTImisVisible= 1; // controlling visibility

    uniform float  CTImminValue= 0.0; // minimum possible value set in configuration
    uniform float  CTImmaxValue= 100.0; // maximum possible value set in configuration
    uniform float  CTImValueRange= 100.0; // range of possible values calculated from above
    uniform float  CTImmaskContribution=1.0; //controls contribution of mask to output color


    float changeClip(float min, float max, float value, float color, float range) {
        if (value < min) {
            return color * (min/ range);
        } else if (value > max) {
            return color * (max/ range);
        } else {
            return color * (value/ range);
        }
    }


    void main() {

    float CTImRes = texture2D(CTIm, TexCoord0).r;



    float todiv = CTImisVisible *CTImmaskContribution;
    FragColor = vec4((  changeClip(CTImminValue,CTImmaxValue,CTImRes,CTImColorMask.r,CTImValueRange)  + 0.0) / todiv,
                    (  changeClip(CTImminValue,CTImmaxValue,CTImRes,CTImColorMask.g,CTImValueRange)  + 0.0) / todiv,
                    (  changeClip(CTImminValue,CTImmaxValue,CTImRes,CTImColorMask.b,CTImValueRange)  + 0.0) / todiv,
                    1.0); // long product, if mask is invisible it just has full transparency
    }
    """
    # FragColor = vec4((  changeClip(CTImminValue,CTImmaxValue,CTImRes,CTImColorMask.r,CTImValueRange)  + 0.0) / todiv,
    #                 (  changeClip(CTImminValue,CTImmaxValue,CTImRes,CTImColorMask.g,CTImValueRange)  + 0.0) / todiv,
    #                 (  changeClip(CTImminValue,CTImmaxValue,CTImRes,CTImColorMask.b,CTImValueRange)  + 0.0) / todiv,
    #                 1.0); // long product, if mask is invisible it just has full transparency
    # }


fid = h5open("/media/jm/hddData/projects/MedEye3d.jl/docs/src/data/ct_pixels.h5", "r")

elements = Face{3,UInt32}[(0, 1, 2),          # the first triangle
  (2, 3, 0)]          # the second triangle


  mainImageQuadVert = Float32.([
    # positions                  // colors           // texture coords
    0.9, 1.0 , 0.0, 1.0, 0.0, 0.0, 1.0, 1.0,   # top right
    0.9, -1.0 , 0.0, 0.0, 1.0, 0.0, 1.0, 0.0,   # bottom right
    -1.0 , -1.0 , 0.0, 0.0, 0.0, 1.0, 0.0, 0.0,   # bottom left
    -1.0 , 1.0 , 0.0, 1.0, 1.0, 0.0, 0.0, 1.0    # top left
  ])

function initializeWindow(windowWidth::Int, windowHeight::Int)
    GLFW.Init()
    # Create a windowed mode window and its OpenGL context
    window = GLFW.CreateWindow(windowWidth, windowHeight, "Segmentation Visualization")
    # Make the window's context current
    GLFW.MakeContextCurrent(window)
    GLFW.ShowWindow(window)
    GLFW.SetWindowSize(window, windowWidth, windowHeight) # Seems to be necessary to guarantee that window > 0
    glViewport(0, 0, windowWidth, windowHeight)
    glDisable(GL_LIGHTING)
    glEnable(GL_TEXTURE_2D)
    return window
end #initializeWindow


function createShader(source, typ)
    # Create the shader
    shader = glCreateShader(typ)::GLuint
    if shader == 0
        error("Error creating shader: ", glErrorMessage())
    end
    # Compile the shader
    glShaderSource(shader, 1, convert(Ptr{UInt8}, pointer([convert(Ptr{GLchar}, pointer(source))])), C_NULL)
    glCompileShader(shader)
    # Check for errors
    # !validateShader(shader) && error("Shader creation error: ", getInfoLog(shader))
    return shader
end

function createAndInitShaderProgram(vertex_shader::UInt32,fragment_shader_source)::Tuple{UInt32,UInt32}
    fragment_shader = createShader(fragment_shader_source, GL_FRAGMENT_SHADER) 
    shader_program = glCreateProgram()
    glAttachShader(shader_program, fragment_shader)
    glAttachShader(shader_program, vertex_shader)
    glLinkProgram(shader_program)
    return fragment_shader, shader_program

end#createShaderProgram

function createVertexBuffer()
    vao = Ref(GLuint(0))
    glGenVertexArrays(1, vao)
    glBindVertexArray(vao[])
    return vao
end #createVertexBuffer


function createDAtaBuffer(positions)
    vbo = Ref(GLuint(0))   # initial value is irrelevant, just allocate space
    glGenBuffers(1, vbo)
    glBindBuffer(GL_ARRAY_BUFFER, vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(positions), positions, GL_STATIC_DRAW)
    return vbo
end #createDAtaBuffer

function createElementBuffer(elements)
    ebo = Ref(GLuint(0))
    glGenBuffers(1, ebo)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo[])
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(elements), elements, GL_STATIC_DRAW)
    return ebo
end #createElementBuffer

function encodeDataFromDataBuffer()
    typee = Float32

    # position attribute
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(typee), C_NULL)
    glEnableVertexAttribArray(0)
    # color attribute
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(typee), Ptr{Nothing}(3 * sizeof(typee)))
    glEnableVertexAttribArray(1)
    # texture coord attribute
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(typee), Ptr{Nothing}(6 * sizeof(typee)))
    glEnableVertexAttribArray(2)

end #encodeDataFromDataBuffer


function createTexture(juliaDataType::Type{juliaDataTyp}, width::Int32, height::Int32, GL_RType::UInt32=GL_R8UI, OpGlType=GL_UNSIGNED_BYTE) where {juliaDataTyp}


    #The texture we're going to render to
    texture = Ref(GLuint(0))
    glGenTextures(1, texture)
    glBindTexture(GL_TEXTURE_2D, texture[])

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0)
    #we just assign storage
    glTexStorage2D(GL_TEXTURE_2D, 1, GL_RType, width, height)


    return texture
end




function getProperGL_TEXTURE(index::Int)::UInt32
    return eval(Meta.parse("GL_TEXTURE$(index)"))
end#getProperGL_TEXTURE


window = initializeWindow(1000,1000)
vertex_shader = createShader(vertex_shader_code, GL_VERTEX_SHADER)
fragment_shader_main, shader_program = createAndInitShaderProgram(vertex_shader,fragment_shader_source)
glUseProgram(shader_program)

VAO=createVertexBuffer()

vbo = createDAtaBuffer(mainImageQuadVert)
ebo = createElementBuffer(elements)

encodeDataFromDataBuffer()
GLFW.MakeContextCurrent(window)

#uniforms
n= "CTIm"
samplerName=n
samplerRef=glGetUniformLocation(shader_program, n)

#data from hdf5
dat= Float32.(read(fid, "data")[:,:,20])

#setup texture
textUreId=createTexture(Float32,Int32(size(dat)[1]),Int32(size(dat)[2]), GL_R32F, GL_FLOAT)
index=0

glActiveTexture(textUreId[])
glUniform1i(samplerRef, index)

glBindTexture(GL_TEXTURE_2D, textUreId[])
xoffset=0
yoffset=0
widthh=size(dat)[1]
heightt=size(dat)[2]

glTexSubImage2D(GL_TEXTURE_2D, 0, xoffset, yoffset, widthh, heightt, GL_RED, GL_FLOAT, collect(dat))


glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, C_NULL)

glUseProgram(shader_program)
glBindBuffer(GL_ARRAY_BUFFER, vbo[])
glBufferData(GL_ARRAY_BUFFER, sizeof(mainImageQuadVert), mainImageQuadVert, GL_STATIC_DRAW) 



###draw texture 
glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, C_NULL)
GLFW.SwapBuffers(window)


# Draw line
glBindBuffer(GL_ARRAY_BUFFER, 0)
# Vertex data for a line
vertices = Float32[
    0.5, 0.5, 0.1,  # top right
    0.5, -0.5, 0.1,  # bottom right
    -0.5, -0.5, 0.1,  # bottom left
    -0.5, 0.5, 0.1   # top left
]

# Indices for drawing lines
indices = UInt32[
    0, 1,  # Line from top right to bottom right
    2, 3   # Line from bottom left to top left
]


vao = Ref(GLuint(0))
glGenVertexArrays(1, vao)
glBindVertexArray(0)
glBindVertexArray(vao[])

# Generate and bind a Vertex Buffer Object
vbo = Ref(GLuint(0))
glGenBuffers(1, vbo)
glBindBuffer(GL_ARRAY_BUFFER, 0)
glBindBuffer(GL_ARRAY_BUFFER, vbo[])
glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)

# Generate and bind an Element Buffer Object
ebo = Ref(GLuint(0))
glGenBuffers(1, ebo)
glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0)
glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo[])
glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW)

# Set vertex attribute pointers
glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(Float32), Ptr{Nothing}(0))
glEnableVertexAttribArray(0)

# Unbind the VBO (the VAO will remember the settings)
glBindBuffer(GL_ARRAY_BUFFER, 0)
glBindVertexArray(0)
glBindVertexArray(vao[])
glClear(GL_COLOR_BUFFER_BIT)
glDrawElements(GL_LINES, 4, GL_UNSIGNED_INT, C_NULL)
glBindVertexArray(0)

# Swap front and back buffers
GLFW.SwapBuffers(window)


#render onto the screen
# basicRender(window)
glFinish()
