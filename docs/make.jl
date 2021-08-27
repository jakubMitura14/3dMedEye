using Documenter
using NuclearMedEye

makedocs(
    sitename = "NuclearMedEye",
    format = Documenter.HTML(),
    modules = [NuclearEye,SegmentationDisplay,ReactingToInput,reactToKeyboard,ReactOnMouseClickAndDrag,ReactToScroll,PrepareWindow,TextureManag,DisplayWords,Uniforms,ShadersAndVerticiesForText,ShadersAndVerticies,OpenGLDisplayUtils, CustomFragShad, PrepareWindowHelpers, StructsManag,forDisplayStructs,DataStructs,FromSegmentationEvaluation,ModernGlUtil]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#