using System;
using System.Collections;
using System.Collections.Generic;
using UnityEditor.Search;
using UnityEngine;

public class _ShellController : MonoBehaviour
{
    public Renderer Target;
    public Shader ShellShader;
    private Material BaseMat;



    [Header("毛发颜色")]
    public Color FurColor;
    public Color FurRootColor;
    public Color FurSpecularColor;
    public Color FurRimColor;

    [Header("毛发光照")]
    [Range(0,16)]
    public float Shininess;             // 光泽度
    [Range(0,10)]
    public float RimPower;              // 边缘光强度
    [Range(0,5)]
    public float RootStrength = 1;             // 根部颜色强度

    [Range(-2,5)]
    public float AOStrength = 1;            // 环境光遮蔽强度
    public Color OcclusionColor;        // 环境光遮蔽颜色

    // 光线穿透
    [Range(-0.5f,0.5f)]
    public float FurTransmissionIntensity = 1;  
    [Range(-2,2)]
    public float FurDirLightExposure = 1;
    public Color DirLightColor = new Vector4(1,1,1,1);

    [Header("各向异性高光")]
    [Range(-1,1)]
    public float AnisoBias = 0.0f;         // 切线偏移
    [Range(1,100)]
    public float AnisoExponent = 20;        // 各向异性锐度
    [Range(0,1)]
    public float AnisoStrength = 0.5f;      // 各向异性强度


    [Header("毛发参数")]
    public Texture2D FurPattern;        // 毛发图案纹理
    public Vector4 SubTex_ST = new Vector4(1,1,0,0);           
    public int LayerCount = 10;         // 毛发层数
    public float FurLength = 0.5f;      // 毛发长度
    public Vector3 FurForce;            // 毛发受力

    public Vector4 UVoffset;            //UV偏移：XY=UV偏移;ZW=UV扰动

    public Texture2D FurFlowmap;

    [Range(1, 10)]
    public float FurTenacity = 1;

    GameObject[] layers;

    [Header("受力动态响应系数")]
    public float transRadio = 20;
    public float rotationRadio = 10;


    

    public bool isEditFur = false;

    void Start(){
        UpdateShellRunTime();
    }

    private void Update()
    {
        if(isEditFur)
            UpdateShellRunTime();  
        else
            UpdateShellTrans(); 
    }


    public void UpdateShellRunTime(){
        ClearShellRunTime();
        CreateShell();
    }

    void UpdateShellTrans(){
        if(layers == null || layers.Length == 0){
            return;
        }
        for(int i = 0; i < layers.Length; i++){
            //依据层数、毛发长度和毛发硬度计算lerp速度
            float lerpSpeed = (layers.Length-i) * (1.0f / layers.Length)* FurTenacity;

            //让Shell的位置和旋转Lerp到目标模型
            layers[i].gameObject.transform.position = Vector3.Lerp(layers[i].gameObject.transform.position, Target.transform.position, lerpSpeed * Time.deltaTime * transRadio);
            layers[i].gameObject.transform.rotation = Quaternion.Lerp(layers[i].gameObject.transform.rotation, Target.transform.rotation, lerpSpeed * Time.deltaTime * rotationRadio);
        }
    }


    public void UpdateShellEditor()
    {
        ClearShellEditor();
        CreateShell();
    }

    public void ClearShellEditor()
    {
        if (layers == null || layers.Length == 0)
        {
            return;
        }

        GameObject[] shells = GameObject.FindGameObjectsWithTag("Shell");

        for (int i = 0; i < shells.Length; i++)
        {
            DestroyImmediate(shells[i].gameObject);
        }
    }



    public void ClearShellRunTime(){
        if(layers == null || layers.Length == 0){
            return;
        }
        for(int i = 0; i < layers.Length; i++){
            Destroy(layers[i].gameObject);
        }
    }

    public void CreateShell(){
        // 毛发层
        layers = new GameObject[LayerCount];
        float furOffset = 1.0f / LayerCount;    //每层毛发偏移量
        for (int i = 0; i < LayerCount; i++){
            // 复制原模型
            GameObject layer = Instantiate(Target.gameObject, Target.transform.position, Target.transform.rotation);
            layer.hideFlags = HideFlags.HideInHierarchy;
            layer.tag = "Shell";

            // 用ShellShader创建Shell材质
            layer.GetComponent<Renderer>().sharedMaterial = new Material(ShellShader);
            // 传参
            layer.GetComponent<Renderer>().sharedMaterial.SetColor("_Color", FurColor);
            layer.GetComponent<Renderer>().sharedMaterial.SetColor("_RootColor", FurRootColor);
            layer.GetComponent<Renderer>().sharedMaterial.SetColor("_RimColor", FurRimColor);
            layer.GetComponent<Renderer>().sharedMaterial.SetColor("_Specular", FurSpecularColor);
            layer.GetComponent<Renderer>().sharedMaterial.SetFloat("_Shininess", Shininess);
            layer.GetComponent<Renderer>().sharedMaterial.SetFloat("_RimPower", RimPower);
            layer.GetComponent<Renderer>().sharedMaterial.SetFloat("_RootStrength", RootStrength);
            layer.GetComponent<Renderer>().sharedMaterial.SetTexture("_FurTex",FurPattern);
            layer.GetComponent<Renderer>().sharedMaterial.SetVector("_SubTex_ST", SubTex_ST);
            layer.GetComponent<Renderer>().sharedMaterial.SetFloat("_FurLength", FurLength);
            // 环境光遮蔽
            layer.GetComponent<Renderer>().sharedMaterial.SetFloat("_AOStrength", AOStrength);
            layer.GetComponent<Renderer>().sharedMaterial.SetColor("_OcclusionColor", OcclusionColor);
            // 不同层 有不同偏移参数
            layer.GetComponent<Renderer>().sharedMaterial.SetFloat("_LayerOffset", i * furOffset);
            // 毛发偏移（受力）
            layer.GetComponent<Renderer>().sharedMaterial.SetVector("_ForceOffset", FurForce * Mathf.Pow(i * furOffset, FurTenacity));
            layer.GetComponent<Renderer>().sharedMaterial.SetVector("_UVoffset", UVoffset);
            // 光线穿透
            layer.GetComponent<Renderer>().sharedMaterial.SetFloat("_FurTransmissionIntensity", FurTransmissionIntensity);
            layer.GetComponent<Renderer>().sharedMaterial.SetFloat("_FurDirLightExposure", FurDirLightExposure);
            layer.GetComponent<Renderer>().sharedMaterial.SetColor("_DirLightColor", DirLightColor);
            // 各向异性
            layer.GetComponent<Renderer>().sharedMaterial.SetFloat("_AnisoBias", AnisoBias);
            layer.GetComponent<Renderer>().sharedMaterial.SetFloat("_AnisoExponent", AnisoExponent);
            layer.GetComponent<Renderer>().sharedMaterial.SetFloat("_AnisoStrength", AnisoStrength);

            // 防止深度剔除
            layer.GetComponent<Renderer>().sharedMaterial.renderQueue = 3000 + i;
            layer.GetComponent<Renderer>().sharedMaterial.SetTexture("_FurFlowMap", FurFlowmap);

            layers[i] = layer;

        }

    }

}
