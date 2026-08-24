/*
 *  Copyright (C) 2005-2018 Team Kodi
 *  This file is part of Kodi - https://kodi.tv
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 *  See LICENSES/README.md for more information.
 */

#include "SoLoader.h"

//#include "CompileInfo.h"
#include "filesystem/SpecialProtocol.h"
#include "utils/URIUtils.h"
#include "utils/log.h"

#if defined(TARGET_DARWIN_EMBEDDED)
#include "platform/darwin/DarwinUtils.h"
#endif

#include <dlfcn.h>

SoLoader::SoLoader(const std::string &so, bool bGlobal) : LibraryLoader(so)
{
  m_soHandle = NULL;
  m_bGlobal = bGlobal;
  m_bLoaded = false;
}

SoLoader::~SoLoader()
{
  if (m_bLoaded)
    Unload();
}

bool SoLoader::Load()
{
  if (m_soHandle != NULL)
    return true;

  std::string strFileName= CSpecialProtocol::TranslatePath(GetFileName());
  if (strFileName == "xbmc.so")
  {
    CLog::Log(LOGDEBUG, "Loading Internal Library");
    m_soHandle = RTLD_DEFAULT;
  }
  else
  {
    if (!PerformLoad(strFileName))
    {
#if defined(TARGET_DARWIN_EMBEDDED)
      // AppStore requires all dylibs to be in .app/Frameworks in framework format, search there as well
      //        const auto dylibExtension = CCompileInfo::CCompileInfo::GetSharedLibrarySuffix();
      //        auto stem = URIUtils::GetFileName(strFileName);
      //        if (stem.ends_with(dylibExtension))
      //            stem.resize(stem.size() - dylibExtension.size());
      auto stem = URIUtils::GetFileName(strFileName);
      URIUtils::RemoveExtension(stem);

      // technically correct way to find binary in a framework is to read CFBundleExecutable from Info.plist
      // but since we package dylibs into frameworks ourselves, we already know the layout
      const auto frameworkBinary = URIUtils::AddFileToFolder(CDarwinUtils::GetFrameworkPath(false),
                                                             stem + ".framework", stem);
      if (!PerformLoad(frameworkBinary))
        return false;
#else
      return false;
#endif
    }
  }
  m_bLoaded = true;
  return true;
}

void SoLoader::Unload()
{
  if (m_soHandle)
  {
    if (dlclose(m_soHandle) != 0)
      CLog::Log(LOGERROR, "Unable to unload {}, reason: {}", GetName(), dlerror());
  }
  m_bLoaded = false;
  m_soHandle = NULL;
}

int SoLoader::ResolveExport(const char* symbol, void** f, bool logging)
{
  if (!m_bLoaded && !Load())
  {
    if (logging)
      CLog::Log(LOGWARNING, "Unable to resolve: {} {}, reason: so not loaded", GetName(), symbol);
    return 0;
  }

  void* s = dlsym(m_soHandle, symbol);
  if (!s)
  {
    if (logging)
      CLog::Log(LOGWARNING, "Unable to resolve: {} {}, reason: {}", GetName(), symbol, dlerror());
    return 0;
  }

  *f = s;
  return 1;
}

bool SoLoader::IsSystemDll()
{
  return false;
}

HMODULE SoLoader::GetHModule()
{
  return m_soHandle;
}

bool SoLoader::HasSymbols()
{
  return false;
}

bool SoLoader::PerformLoad(const std::string& libPath)
{
  CLog::Log(LOGDEBUG, "Loading: {}", libPath);
  const int flags = RTLD_LAZY;
  m_soHandle = dlopen(libPath.c_str(), flags);
  if (m_soHandle == nullptr)
    CLog::Log(LOGERROR, "Unable to load {}, reason: {}", libPath, dlerror());
  return m_soHandle != nullptr;
}
